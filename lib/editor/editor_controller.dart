import 'package:flutter/painting.dart';

import '../core/utils/id_generator.dart';
import '../math/vec2.dart';
import '../models/anchor_point.dart';
import '../models/fill_style.dart';
import '../models/path_object.dart';
import '../models/text_object.dart';
import '../models/vector_document.dart';
import '../models/vector_object.dart';
import '../storage/document_export_service.dart';
import '../storage/project_storage.dart';
import 'artwork_bounds_service.dart';
import 'document_controller.dart';
import 'editor_commands.dart';
import 'grouping_service.dart';
import 'object_naming_service.dart';
import 'selection_controller.dart';
import 'text_editing_session.dart';
import 'tool_controller.dart';
import 'viewport_controller.dart';

/// Coordinates multi-controller workflows across document, selection, tools,
/// inline text editing, grouping, artwork navigation, `.vectra` persistence,
/// image/SVG import, and SVG/PNG/JPEG export.
class EditorController {
  final DocumentController documentController;
  final SelectionController selectionController;
  final ToolController toolController;
  final ViewportController viewportController;
  final ProjectStorage projectStorage;

  const EditorController({
    required this.documentController,
    required this.selectionController,
    required this.toolController,
    required this.viewportController,
    required this.projectStorage,
  });

  VectorDocument get currentDocument => documentController.state.document;
  Set<String> get selectedIds => selectionController.state.selectedIds;
  InlineTextEditingSession? get activeTextSession =>
      toolController.state.activeTextSession;

  bool get canGroupSelection =>
      GroupingService.canGroup(currentDocument, selectedIds);
  bool get canUngroupSelection =>
      GroupingService.canUngroup(currentDocument, selectedIds);

  /// Switches the active tool while safely committing any active inline text session
  /// or in-progress Pen path.
  void activateTool(EditorToolType nextTool) {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }

    if (toolController.state.activeTool == nextTool) return;

    if (toolController.state.activeTool == EditorToolType.pen &&
        toolController.state.transient.hasActivePenPath) {
      commitActivePenPath(closed: false);
    } else if (documentController.hasActiveTransaction) {
      documentController.cancelInteractiveTransaction();
    }

    toolController.selectTool(nextTool);
  }

  // ---------------------------------------------------------------------------
  // INLINE TEXT CREATION & EDITING WORKFLOW
  // ---------------------------------------------------------------------------

  /// Creates a new Point Text or Area Frame Text object at `(x, y)` and immediately
  /// opens a live viewport-aligned inline editing session.
  void createAndBeginInlineText({
    required double x,
    required double y,
    double? frameWidth,
    double? frameHeight,
  }) {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }

    final doc = currentDocument;
    final toolState = toolController.state;
    final newId = IdGenerator.objectId();
    final prevSel = selectedIds;

    final newTextObj = TextObject(
      id: newId,
      name: doc.nextObjectName(VectorObjectType.text),
      layerId: doc.activeLayer.id,
      text: '',
      x: x,
      y: y,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      fontFamily: toolState.defaultFontFamily,
      fontSize: toolState.defaultFontSize,
      fontWeightValue: toolState.defaultFontWeight,
      isItalic: toolState.defaultItalic,
      textAlign: toolState.defaultTextAlign,
      fill: toolState.defaultTextFill,
    );

    documentController.beginInteractiveTransaction(currentSelection: prevSel);
    final updatedDoc = doc.addObject(newTextObj);
    documentController.updateInteractiveDocument(updatedDoc);
    selectionController.selectSingle(newId);

    toolController.setActiveTextSession(
      InlineTextEditingSession(
        objectId: newId,
        isNewlyCreated: true,
        preSessionDocument: doc,
        preSessionSelection: prevSel,
        initialText: '',
      ),
    );
    documentController.setStatusMessage(
      frameWidth != null
          ? 'Editing Frame Text — Enter for new line, Ctrl+Enter or click outside to finish, Esc to cancel'
          : 'Editing Point Text — Enter for new line, Ctrl+Enter or click outside to finish, Esc to cancel',
    );
  }

  /// Opens an inline viewport text editing session for an existing [TextObject].
  void beginInlineTextEditing(String objectId) {
    if (activeTextSession?.objectId == objectId) return;
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }

    final doc = currentDocument;
    final existing = doc.findObjectById(objectId);
    if (existing is! TextObject) return;
    if (!doc.isObjectEffectivelyVisible(objectId) ||
        doc.isObjectEffectivelyLocked(objectId)) {
      return;
    }

    final prevSel = selectedIds;
    documentController.beginInteractiveTransaction(currentSelection: prevSel);
    selectionController.selectSingle(objectId);

    toolController.setActiveTextSession(
      InlineTextEditingSession(
        objectId: objectId,
        isNewlyCreated: false,
        preSessionDocument: doc,
        preSessionSelection: prevSel,
        initialText: existing.text,
      ),
    );
    documentController.setStatusMessage(
      'Editing "${existing.name}" — Enter for new line, Ctrl+Enter or click outside to finish, Esc to revert',
    );
  }

  /// Updates the live draft content of the active [TextObject] without creating
  /// per-keystroke undo entries.
  void updateInlineTextDraft(String nextText) {
    final session = activeTextSession;
    if (session == null) return;

    final updated = currentDocument.updateObject(
      session.objectId,
      (obj) => obj is TextObject ? obj.copyWith(text: nextText) : obj,
    );
    documentController.updateInteractiveDocument(updated);
  }

  /// Finalizes the active inline text editing session as a single atomic undo entry.
  /// Empty newly created text sessions are discarded cleanly without leaving ghost objects.
  void commitInlineTextEditing() {
    final session = activeTextSession;
    if (session == null) return;
    toolController.setActiveTextSession(null);

    final liveObj = currentDocument.findObjectById(session.objectId);
    if (liveObj is! TextObject || liveObj.text.trim().isEmpty) {
      documentController.cancelInteractiveTransaction();
      if (!session.isNewlyCreated && liveObj is TextObject) {
        // User cleared all text from an existing TextObject -> remove it cleanly in one undo step
        documentController.executeEdit(
          label: 'Delete Empty Text',
          mutator: (doc) => doc.removeObjects(<String>{session.objectId}),
          beforeSelection: session.preSessionSelection,
          afterSelection: const <String>{},
        );
        selectionController.clearSelection();
      } else {
        selectionController.setSelectedIds(session.preSessionSelection);
        documentController.setStatusMessage('Empty text discarded');
      }
      return;
    }

    if (!session.isNewlyCreated && liveObj.text == session.initialText) {
      documentController.cancelInteractiveTransaction();
      selectionController.selectSingle(session.objectId);
      documentController.setStatusMessage('Ready');
      return;
    }

    documentController.commitInteractiveTransaction(
      label: session.isNewlyCreated ? 'Create Text' : 'Edit Text',
      afterSelection: <String>{session.objectId},
    );
    selectionController.selectSingle(session.objectId);
  }

  /// Cancels an active inline text session (`Escape`), discarding uncommitted creation
  /// or restoring the previous text content.
  void cancelInlineTextEditing() {
    final session = activeTextSession;
    if (session == null) return;
    toolController.setActiveTextSession(null);
    documentController.cancelInteractiveTransaction();
    selectionController.setSelectedIds(session.preSessionSelection);
    selectionController.reconcileWithDocument(currentDocument);
    documentController.setStatusMessage('Canceled text editing');
  }

  // ---------------------------------------------------------------------------
  // UNIFIED OBJECT RENAMING & GROUPING
  // ---------------------------------------------------------------------------

  /// Renames any object (shape, path, text, image, or group) from Floating Tags,
  /// Layers Panel, or Inspector with empty-string protection and undo/redo support.
  void renameObject(String objectId, String rawName) {
    final existing = currentDocument.findObjectById(objectId);
    if (existing == null) return;

    final sanitized = ObjectNamingService.sanitizeName(
      rawName,
      fallbackName: existing.name,
    );
    if (sanitized == existing.name) return;

    documentController.executeEdit(
      label: 'Rename to "$sanitized"',
      mutator: (doc) => doc.updateObject(
        objectId,
        (curr) => curr.withName(sanitized),
      ),
      beforeSelection: selectedIds,
    );
  }

  /// Groups 2+ selected unlocked objects into a [GroupObject] (`Ctrl+G`).
  void groupSelection() {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }
    final prevSel = selectedIds;
    if (!canGroupSelection) return;

    String? createdGroupId;
    documentController.executeEdit(
      label: 'Group ${prevSel.length} Objects',
      mutator: (doc) {
        final res = GroupingService.groupSelectedObjects(doc, prevSel);
        createdGroupId = res.groupId;
        return res.document;
      },
      beforeSelection: prevSel,
      afterSelection:
          createdGroupId != null ? <String>{createdGroupId!} : prevSel,
    );

    if (createdGroupId != null) {
      selectionController.selectSingle(createdGroupId!);
    }
  }

  /// Ungroups selected [GroupObject]s back into individual selectable objects (`Ctrl+Shift+G`).
  void ungroupSelection() {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }
    final prevSel = selectedIds;
    if (!canUngroupSelection) return;

    Set<String> restoredIds = const <String>{};
    documentController.executeEdit(
      label: 'Ungroup Objects',
      mutator: (doc) {
        final res = GroupingService.ungroupSelectedObjects(doc, prevSel);
        restoredIds = res.restoredChildIds;
        return res.document;
      },
      beforeSelection: prevSel,
      afterSelection: restoredIds,
    );

    if (restoredIds.isNotEmpty) {
      selectionController.setSelectedIds(restoredIds);
    }
  }

  // ---------------------------------------------------------------------------
  // ARTWORK NAVIGATION ("FIND MY ARTWORK", FOCUS SELECTION, RESET VIEW)
  // ---------------------------------------------------------------------------

  /// Pans and zooms the viewport so all visible artwork in the document fits
  /// comfortably with padding. Falls back cleanly to artboard bounds if empty.
  void findMyArtwork() {
    final doc = currentDocument;
    final bounds = ArtworkBoundsService.computeVisibleArtworkBounds(doc);
    if (bounds == null) {
      viewportController.fitArtboard(
        docWidth: doc.width,
        docHeight: doc.height,
      );
      documentController.setStatusMessage(
        'No visible artwork objects — fitted artboard to viewport',
      );
      return;
    }

    viewportController.fitBounds(bounds, padding: 72.0, maxAutoZoom: 4.0);
    documentController.setStatusMessage('Fitted all visible artwork into view');
  }

  /// Pans and zooms the viewport around the currently selected object(s).
  void focusSelection() {
    final doc = currentDocument;
    final bounds =
        ArtworkBoundsService.computeSelectionBounds(doc, selectedIds);
    if (bounds == null) {
      findMyArtwork();
      return;
    }

    viewportController.fitBounds(bounds, padding: 80.0, maxAutoZoom: 6.0);
    documentController.setStatusMessage('Focused viewport on selection');
  }

  /// Resets viewport zoom to 100% centered on the artboard.
  void resetView() {
    final doc = currentDocument;
    viewportController.resetZoomTo100(
      docWidth: doc.width,
      docHeight: doc.height,
    );
    documentController.setStatusMessage('Reset view to 100%');
  }

  // ---------------------------------------------------------------------------
  // PEN TOOL, SELECTION, AND HISTORY OPERATIONS
  // ---------------------------------------------------------------------------

  /// Commits the temporary Pen Tool anchors into a persistent [PathObject].
  void commitActivePenPath({required bool closed}) {
    final transient = toolController.state.transient;
    final anchors = transient.penAnchors;
    toolController.clearTransient();

    if (anchors.length < 2) {
      documentController
          .setStatusMessage('Pen path discarded (fewer than 2 anchors)');
      return;
    }

    final doc = currentDocument;
    final newId = IdGenerator.objectId();
    final pathObject = PathObject(
      id: newId,
      name: doc.nextObjectName(VectorObjectType.path),
      layerId: doc.activeLayer.id,
      anchors: anchors,
      closed: closed,
      fill: closed ? toolController.state.defaultFill : FillStyle.none,
      stroke: toolController.state.defaultStroke.copyWith(isEnabled: true),
    );

    final prevSel = selectedIds;
    final nextSel = <String>{newId};
    documentController.executeEdit(
      label: closed ? 'Create Closed Path' : 'Create Open Path',
      mutator: (d) => d.addObject(pathObject),
      beforeSelection: prevSel,
      afterSelection: nextSel,
    );
    selectionController.selectSingle(newId);
  }

  /// Cancels any temporary inline text session, drawing operation, or active drag gesture.
  void cancelActiveOperation() {
    if (activeTextSession != null) {
      cancelInlineTextEditing();
      return;
    }
    if (toolController.state.transient.hasActivePenPath ||
        toolController.state.transient.draftObject != null ||
        toolController.state.transient.marqueeBounds != null) {
      toolController.clearTransient();
      documentController.setStatusMessage('Canceled drawing preview');
      return;
    }
    if (documentController.hasActiveTransaction) {
      documentController.cancelInteractiveTransaction();
      return;
    }
    selectionController.clearSelection();
  }

  void undo() {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }
    final restoredSelection = documentController.undo();
    if (restoredSelection != null) {
      selectionController.setSelectedIds(restoredSelection);
      selectionController.reconcileWithDocument(currentDocument);
    }
  }

  void redo() {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }
    final restoredSelection = documentController.redo();
    if (restoredSelection != null) {
      selectionController.setSelectedIds(restoredSelection);
      selectionController.reconcileWithDocument(currentDocument);
    }
  }

  void deleteSelection() {
    if (activeTextSession != null) return;
    final ids = selectedIds;
    if (ids.isEmpty) return;

    documentController.executeEdit(
      label: ids.length == 1 ? 'Delete Object' : 'Delete ${ids.length} Objects',
      mutator: (doc) => doc.removeObjects(ids),
      beforeSelection: ids,
      afterSelection: const <String>{},
    );
    selectionController.clearSelection();
  }

  void duplicateSelection() {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }
    final ids = selectedIds;
    if (ids.isEmpty) return;

    Set<String> newIds = const <String>{};
    documentController.executeEdit(
      label: ids.length == 1 ? 'Duplicate Object' : 'Duplicate Objects',
      mutator: (doc) {
        final res = EditorCommands.duplicateObjects(doc, ids);
        newIds = res.createdIds;
        return res.document;
      },
      beforeSelection: ids,
      afterSelection: newIds,
    );

    if (newIds.isNotEmpty) {
      selectionController.setSelectedIds(newIds);
    }
  }

  void selectAllUnlocked() {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }
    final doc = currentDocument;
    final ids = <String>{};
    for (final layer in doc.layers) {
      if (!layer.visible || layer.locked) continue;
      for (final obj in layer.objects) {
        if (obj.visible && !obj.locked) {
          ids.add(obj.id);
        }
      }
    }
    selectionController.setSelectedIds(ids);
  }

  void moveSelectedInLayer(int delta) {
    final primaryId = selectionController.state.primarySelectedId;
    if (primaryId == null) return;
    documentController.executeEdit(
      label: delta > 0 ? 'Bring Forward' : 'Send Backward',
      mutator: (doc) => doc.moveObjectInLayer(primaryId, delta),
      beforeSelection: selectedIds,
    );
  }

  /// Toggles or sets the selected anchor node's [NodeType] (`corner` vs `smooth`).
  void setSelectedAnchorNodeType(NodeType targetType) {
    final primaryId = selectionController.state.primarySelectedId;
    final anchorIdx = selectionController.state.selectedAnchorIndex;
    if (primaryId == null || anchorIdx == null) return;

    final obj = currentDocument.findObjectById(primaryId);
    if (obj is! PathObject || anchorIdx < 0 || anchorIdx >= obj.anchors.length) {
      return;
    }

    documentController.executeEdit(
      label: 'Set Node ${targetType.name}',
      mutator: (doc) => EditorCommands.updatePathAnchor(doc, primaryId, anchorIdx, (anchor) {
        if (targetType == NodeType.corner) {
          return anchor.copyWith(
            nodeType: NodeType.corner,
            handleIn: Vec2.zero,
            handleOut: Vec2.zero,
          );
        }
        if (!anchor.hasHandleIn && !anchor.hasHandleOut) {
          final prevIdx = (anchorIdx - 1 + obj.anchors.length) % obj.anchors.length;
          final nextIdx = (anchorIdx + 1) % obj.anchors.length;
          final tangentDir =
              (obj.anchors[nextIdx].position - obj.anchors[prevIdx].position)
                  .normalized;
          final fallbackDir =
              tangentDir.isZero ? const Vec2(1.0, 0.0) : tangentDir;
          final handleVec = fallbackDir * 32.0;
          return anchor.copyWith(
            nodeType: NodeType.smooth,
            handleOut: handleVec,
            handleIn: -handleVec,
          );
        }
        if (anchor.hasHandleOut) {
          return anchor
              .copyWith(nodeType: targetType)
              .withWorldHandleOut(anchor.worldHandleOut);
        }
        return anchor
            .copyWith(nodeType: targetType)
            .withWorldHandleIn(anchor.worldHandleIn);
      }),
      beforeSelection: selectedIds,
    );
  }

  /// Deletes the currently selected anchor node from a [PathObject] if >2 anchors exist.
  void deleteSelectedAnchor() {
    final primaryId = selectionController.state.primarySelectedId;
    final anchorIdx = selectionController.state.selectedAnchorIndex;
    if (primaryId == null || anchorIdx == null) return;

    final obj = currentDocument.findObjectById(primaryId);
    if (obj is! PathObject || obj.anchors.length <= 2) return;

    documentController.executeEdit(
      label: 'Delete Path Anchor',
      mutator: (doc) => doc.updateObject(
        primaryId,
        (current) => current is PathObject
            ? current.removeAnchorAt(anchorIdx)
            : current,
      ),
      beforeSelection: selectedIds,
    );
    selectionController.selectAnchor(null);
  }

  // ---------------------------------------------------------------------------
  // PROJECT PERSISTENCE, ASSET IMPORT, AND ARTWORK EXPORT
  // ---------------------------------------------------------------------------

  /// Replaces the workspace with a new blank [VectorDocument] and fits it to the viewport.
  void startNewDocument({
    required String name,
    required double width,
    required double height,
    required Color backgroundColor,
  }) {
    if (activeTextSession != null) {
      toolController.setActiveTextSession(null);
    }
    toolController.clearTransient();
    selectionController.clearSelection();
    final newDoc = VectorDocument.createNew(
      name: name,
      width: width,
      height: height,
      backgroundColor: backgroundColor,
    );
    documentController.replaceDocument(
      newDoc,
      statusMessage:
          'Created "${newDoc.name}" (${newDoc.width.round()}×${newDoc.height.round()})',
    );
    viewportController.fitArtboard(
      docWidth: newDoc.width,
      docHeight: newDoc.height,
    );
  }

  /// Opens a `.vectra` project via native desktop file dialog.
  Future<bool> openProject() async {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }
    final loaded = await projectStorage.pickAndOpenProject();
    if (loaded == null) return false;

    toolController.clearTransient();
    selectionController.clearSelection();
    documentController.replaceDocument(
      loaded.document,
      filePath: loaded.filePath,
      statusMessage: 'Opened ${loaded.filePath}',
    );
    viewportController.fitArtboard(
      docWidth: loaded.document.width,
      docHeight: loaded.document.height,
    );
    return true;
  }

  /// Saves to the current `.vectra` path if known, otherwise prompts Save As.
  Future<bool> saveProject() async {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }
    final existingPath = documentController.state.filePath;
    if (existingPath != null && existingPath.isNotEmpty) {
      final savedPath = await projectStorage.saveProjectToPath(
        currentDocument,
        existingPath,
      );
      documentController.markSaved(savedPath);
      return true;
    }
    return saveProjectAs();
  }

  /// Prompts Save As dialog for `.vectra` and writes the editable project file.
  Future<bool> saveProjectAs() async {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }
    final savedPath =
        await projectStorage.pickAndSaveProjectAs(currentDocument);
    if (savedPath == null) return false;
    documentController.markSaved(savedPath);
    return true;
  }

  /// Imports a local PNG, JPEG, or WebP image into the active layer as an undoable edit.
  Future<bool> importRasterImage() async {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }
    final imported =
        await projectStorage.imageImporter.pickAndImportImage(currentDocument);
    if (imported == null) return false;

    final prevSel = selectedIds;
    final newId = imported.imageObject.id;
    documentController.executeEdit(
      label: 'Import Image "${imported.asset.name}"',
      mutator: (doc) =>
          doc.addAsset(imported.asset).addObject(imported.imageObject),
      beforeSelection: prevSel,
      afterSelection: <String>{newId},
    );
    selectionController.selectSingle(newId);
    activateTool(EditorToolType.selection);
    return true;
  }

  /// Imports an external `.svg` vector file as editable VECTRA objects in one undoable transaction.
  Future<bool> importSvgFile() async {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }
    final importedObjects =
        await projectStorage.svgImporter.pickAndImportSvg(currentDocument);
    if (importedObjects == null || importedObjects.isEmpty) return false;

    final prevSel = selectedIds;
    final newIds = importedObjects.map((o) => o.id).toSet();
    documentController.executeEdit(
      label: 'Import SVG (${importedObjects.length} item${importedObjects.length == 1 ? '' : 's'})',
      mutator: (doc) => doc.addObjects(importedObjects),
      beforeSelection: prevSel,
      afterSelection: newIds,
    );
    selectionController.setSelectedIds(newIds);
    activateTool(EditorToolType.selection);
    findMyArtwork();
    return true;
  }

  /// Exports artwork using [config] (SVG, PNG, or JPEG) via the native Save dialog.
  Future<ExportResult?> exportArtwork(ExportConfig config) async {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }
    final result = await projectStorage.exportService.pickAndExport(
      currentDocument,
      config,
    );
    if (result != null) {
      documentController.setStatusMessage(
        'Exported ${result.format.name.toUpperCase()} (${result.pixelWidth}×${result.pixelHeight}) to ${result.filePath}',
      );
    }
    return result;
  }

  /// Prompts Save dialog for `.svg` directly (preserving Phase 1 direct shortcut workflow).
  Future<String?> exportSvg() async {
    if (activeTextSession != null) {
      commitInlineTextEditing();
    }
    final exportedPath = await projectStorage.pickAndExportSvg(currentDocument);
    if (exportedPath != null) {
      documentController.setStatusMessage('Exported SVG to $exportedPath');
    }
    return exportedPath;
  }
}
