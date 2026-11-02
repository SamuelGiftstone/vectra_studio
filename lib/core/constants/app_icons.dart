import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Centralized Phosphor icon definitions used across VECTRA Studio.
class AppIcons {
  AppIcons._();

  // Vector Tools
  static const IconData selection = PhosphorIconsRegular.cursor;
  static const IconData selectionFill = PhosphorIconsFill.cursor;
  static const IconData node = PhosphorIconsRegular.bezierCurve;
  static const IconData pen = PhosphorIconsRegular.penNib;
  static const IconData penFill = PhosphorIconsFill.penNib;
  static const IconData rectangle = PhosphorIconsRegular.square;
  static const IconData ellipse = PhosphorIconsRegular.circle;
  static const IconData line = PhosphorIconsRegular.lineSegment;
  static const IconData polygon = PhosphorIconsRegular.polygon;
  static const IconData star = PhosphorIconsRegular.star;
  static const IconData hand = PhosphorIconsRegular.hand;
  static const IconData text = PhosphorIconsRegular.textT;

  // Typography Formatting
  static const IconData bold = PhosphorIconsRegular.textB;
  static const IconData italic = PhosphorIconsRegular.textItalic;
  static const IconData alignLeft = PhosphorIconsRegular.textAlignLeft;
  static const IconData alignCenter = PhosphorIconsRegular.textAlignCenter;
  static const IconData alignRight = PhosphorIconsRegular.textAlignRight;
  static const IconData alignJustify = PhosphorIconsRegular.textAlignJustify;

  // File, Import & Export Operations
  static const IconData newFile = PhosphorIconsRegular.filePlus;
  static const IconData openFile = PhosphorIconsRegular.folderOpen;
  static const IconData save = PhosphorIconsRegular.floppyDisk;
  static const IconData exportSvg = PhosphorIconsRegular.export;
  static const IconData image = PhosphorIconsRegular.image;

  // Grouping & Object Tags
  static const IconData group = PhosphorIconsRegular.folderSimple;
  static const IconData ungroup = PhosphorIconsRegular.selectionAll;
  static const IconData tag = PhosphorIconsRegular.tag;

  // History & Object Actions
  static const IconData undo = PhosphorIconsRegular.arrowCounterClockwise;
  static const IconData redo = PhosphorIconsRegular.arrowClockwise;
  static const IconData duplicate = PhosphorIconsRegular.copy;
  static const IconData delete = PhosphorIconsRegular.trash;
  static const IconData add = PhosphorIconsRegular.plus;
  static const IconData remove = PhosphorIconsRegular.minus;
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData check = PhosphorIconsRegular.check;

  // Layers & Visibility
  static const IconData layers = PhosphorIconsRegular.stack;
  static const IconData visible = PhosphorIconsRegular.eye;
  static const IconData hidden = PhosphorIconsRegular.eyeSlash;
  static const IconData locked = PhosphorIconsRegular.lockSimple;
  static const IconData unlocked = PhosphorIconsRegular.lockSimpleOpen;
  static const IconData moveUp = PhosphorIconsRegular.caretUp;
  static const IconData moveDown = PhosphorIconsRegular.caretDown;
  static const IconData expand = PhosphorIconsRegular.caretDown;
  static const IconData collapse = PhosphorIconsRegular.caretRight;
  static const IconData rename = PhosphorIconsRegular.pencilSimple;

  // Viewport & Canvas Navigation
  static const IconData zoomIn = PhosphorIconsRegular.magnifyingGlassPlus;
  static const IconData zoomOut = PhosphorIconsRegular.magnifyingGlassMinus;
  static const IconData fitView = PhosphorIconsRegular.cornersOut;
  static const IconData focusSelection = PhosphorIconsRegular.cornersIn;
  static const IconData findArtwork = PhosphorIconsRegular.crosshair;
  static const IconData grid = PhosphorIconsRegular.gridFour;
  static const IconData sliders = PhosphorIconsRegular.slidersHorizontal;
  static const IconData warning = PhosphorIconsRegular.warning;
}

