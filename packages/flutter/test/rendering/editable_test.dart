// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(gspencergoog): Remove this tag once this test's state leaks/test
// dependencies have been fixed.
// https://github.com/flutter/flutter/issues/85160
// Fails with "flutter test --test-randomize-ordering-seed=20210704"
@Tags(<String>['no-shuffle'])

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_canvas.dart';
import 'recording_canvas.dart';
import 'rendering_tester.dart';

class _FakeEditableTextState with TextSelectionDelegate {
  @override
  TextEditingValue textEditingValue = TextEditingValue.empty;

  TextSelection? selection;

  @override
  void hideToolbar([bool hideHandles = true]) { }

  @override
  void userUpdateTextEditingValue(TextEditingValue value, SelectionChangedCause cause) {
    selection = value.selection;
  }

  @override
  void bringIntoView(TextPosition position) { }

  @override
  void cutSelection(SelectionChangedCause cause) { }

  @override
  Future<void> pasteText(SelectionChangedCause cause) {
    return Future<void>.value();
  }

  @override
  void selectAll(SelectionChangedCause cause) { }

  @override
  void copySelection(SelectionChangedCause cause) { }
}

void main() {
  TestRenderingFlutterBinding.ensureInitialized();

  test('RenderEditable respects clipBehavior', () {
    const BoxConstraints viewport = BoxConstraints(maxHeight: 100.0, maxWidth: 1.0);
    final String longString = 'a' * 10000;

    for (final Clip? clip in <Clip?>[null, ...Clip.values]) {
      final TestClipPaintingContext context = TestClipPaintingContext();
      final RenderEditable editable;
      switch (clip) {
        case Clip.none:
        case Clip.hardEdge:
        case Clip.antiAlias:
        case Clip.antiAliasWithSaveLayer:
          editable = RenderEditable(
            text: TextSpan(text: longString),
            textDirection: TextDirection.ltr,
            startHandleLayerLink: LayerLink(),
            endHandleLayerLink: LayerLink(),
            offset: ViewportOffset.zero(),
            textSelectionDelegate: _FakeEditableTextState(),
            selection: const TextSelection(baseOffset: 0, extentOffset: 0),
            clipBehavior: clip!,
          );
          break;
        case null:
          editable = RenderEditable(
            text: TextSpan(text: longString),
            textDirection: TextDirection.ltr,
            startHandleLayerLink: LayerLink(),
            endHandleLayerLink: LayerLink(),
            offset: ViewportOffset.zero(),
            textSelectionDelegate: _FakeEditableTextState(),
            selection: const TextSelection(baseOffset: 0, extentOffset: 0),
          );
          break;
      }
      layout(editable, constraints: viewport, phase: EnginePhase.composite, onErrors: expectNoFlutterErrors);
      context.paintChild(editable, Offset.zero);
      // By default, clipBehavior is Clip.hardEdge.
      expect(context.clipBehavior, equals(clip ?? Clip.hardEdge), reason: 'for $clip');
    }
  });

  test('Reports the real height when maxLines is 1', () {
    const InlineSpan tallSpan = TextSpan(
      style: TextStyle(fontSize: 10),
      children: <InlineSpan>[TextSpan(text: 'TALL', style: TextStyle(fontSize: 100))],
    );
    final BoxConstraints constraints = BoxConstraints.loose(const Size(600, 600));
    final RenderEditable editable = RenderEditable(
      textDirection: TextDirection.ltr,
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      offset: ViewportOffset.zero(),
      textSelectionDelegate: _FakeEditableTextState(),
      text: tallSpan,
    );

    layout(editable, constraints: constraints);
    expect(editable.size.height, 100);
  });

  test('Reports the height of the first line when maxLines is 1', () {
    final InlineSpan multilineSpan = TextSpan(
      text: 'liiiiines\n' * 10,
      style: const TextStyle(fontSize: 10),
    );
    final BoxConstraints constraints = BoxConstraints.loose(const Size(600, 600));
    final RenderEditable editable = RenderEditable(
      textDirection: TextDirection.ltr,
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      offset: ViewportOffset.zero(),
      textSelectionDelegate: _FakeEditableTextState(),
      text: multilineSpan,
    );

    layout(editable, constraints: constraints);
    expect(editable.size.height, 10);
  });

  test('Editable respect clipBehavior in describeApproximatePaintClip', () {
    final String longString = 'a' * 10000;
    final RenderEditable editable = RenderEditable(
      text: TextSpan(text: longString),
      textDirection: TextDirection.ltr,
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      offset: ViewportOffset.zero(),
      textSelectionDelegate: _FakeEditableTextState(),
      selection: const TextSelection(baseOffset: 0, extentOffset: 0),
      clipBehavior: Clip.none,
    );
    layout(editable);

    bool visited = false;
    editable.visitChildren((RenderObject child) {
      visited = true;
      expect(editable.describeApproximatePaintClip(child), null);
    });
    expect(visited, true);
  });

  test('RenderEditable.paint respects offset argument', () {
    const BoxConstraints viewport = BoxConstraints(maxHeight: 1000.0, maxWidth: 1000.0);
    final TestPushLayerPaintingContext context = TestPushLayerPaintingContext();

    const Offset paintOffset = Offset(100, 200);
    const double fontSize = 20.0;
    const Offset endpoint = Offset(0.0, fontSize);

    final RenderEditable editable = RenderEditable(
      text: const TextSpan(
        text: 'text',
        style: TextStyle(
          fontSize: fontSize,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      offset: ViewportOffset.zero(),
      textSelectionDelegate: _FakeEditableTextState(),
      selection: const TextSelection(baseOffset: 0, extentOffset: 0),
    );
    layout(editable, constraints: viewport, phase: EnginePhase.composite);
    editable.paint(context, paintOffset);

    final List<LeaderLayer> leaderLayers = context.pushedLayers.whereType<LeaderLayer>().toList();
    expect(leaderLayers, hasLength(1), reason: '_paintHandleLayers will paint a LeaderLayer');
    expect(leaderLayers.single.offset, endpoint + paintOffset, reason: 'offset should respect paintOffset');
  });

  test('editable intrinsics', () {
    final TextSelectionDelegate delegate = _FakeEditableTextState();
    final RenderEditable editable = RenderEditable(
      text: const TextSpan(
        style: TextStyle(height: 1.0, fontSize: 10.0, fontFamily: 'Ahem'),
        text: '12345',
      ),
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      textDirection: TextDirection.ltr,
      locale: const Locale('ja', 'JP'),
      offset: ViewportOffset.zero(),
      textSelectionDelegate: delegate,
    );
    expect(editable.getMinIntrinsicWidth(double.infinity), 50.0);
    // The width includes the width of the cursor (1.0).
    expect(editable.getMaxIntrinsicWidth(double.infinity), 52.0);
    expect(editable.getMinIntrinsicHeight(double.infinity), 10.0);
    expect(editable.getMaxIntrinsicHeight(double.infinity), 10.0);

    expect(
      editable.toStringDeep(minLevel: DiagnosticLevel.info),
      equalsIgnoringHashCodes(
        'RenderEditable#00000 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE DETACHED\n'
        ' │ parentData: MISSING\n'
        ' │ constraints: MISSING\n'
        ' │ size: MISSING\n'
        ' │ cursorColor: null\n'
        ' │ showCursor: ValueNotifier<bool>#00000(false)\n'
        ' │ maxLines: 1\n'
        ' │ minLines: null\n'
        ' │ selectionColor: null\n'
        ' │ textScaleFactor: 1.0\n'
        ' │ locale: ja_JP\n'
        ' │ selection: null\n'
        ' │ offset: _FixedViewportOffset#00000(offset: 0.0)\n'
        ' ╘═╦══ text ═══\n'
        '   ║ TextSpan:\n'
        '   ║   inherit: true\n'
        '   ║   family: Ahem\n'
        '   ║   size: 10.0\n'
        '   ║   height: 1.0x\n'
        '   ║   "12345"\n'
        '   ╚═══════════\n',
      ),
    );
  });

  // Test that clipping will be used even when the text fits within the visible
  // region if the start position of the text is offset (e.g. during scrolling
  // animation).
  test('correct clipping', () {
    final TextSelectionDelegate delegate = _FakeEditableTextState();
    final RenderEditable editable = RenderEditable(
      text: const TextSpan(
        style: TextStyle(height: 1.0, fontSize: 10.0, fontFamily: 'Ahem'),
        text: 'A',
      ),
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      textDirection: TextDirection.ltr,
      locale: const Locale('en', 'US'),
      offset: ViewportOffset.fixed(10.0),
      textSelectionDelegate: delegate,
      selection: const TextSelection.collapsed(
        offset: 0,
      ),
    );
    layout(editable, constraints: BoxConstraints.loose(const Size(500.0, 500.0)));
    // Prepare for painting after layout.
    pumpFrame(phase: EnginePhase.compositingBits);
    expect(
      (Canvas canvas) => editable.paint(TestRecordingPaintingContext(canvas), Offset.zero),
      paints..clipRect(rect: const Rect.fromLTRB(0.0, 0.0, 500.0, 10.0)),
    );
  });

  test('Can change cursor color, radius, visibility', () {
    final TextSelectionDelegate delegate = _FakeEditableTextState();
    final ValueNotifier<bool> showCursor = ValueNotifier<bool>(true);
    EditableText.debugDeterministicCursor = true;

    final RenderEditable editable = RenderEditable(
      backgroundCursorColor: Colors.grey,
      textDirection: TextDirection.ltr,
      cursorColor: const Color.fromARGB(0xFF, 0xFF, 0x00, 0x00),
      offset: ViewportOffset.zero(),
      textSelectionDelegate: delegate,
      text: const TextSpan(
        text: 'test',
        style: TextStyle(
          height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
        ),
      ),
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      selection: const TextSelection.collapsed(
        offset: 4,
        affinity: TextAffinity.upstream,
      ),
    );

    layout(editable);

    editable.layout(BoxConstraints.loose(const Size(100, 100)));
    // Prepare for painting after layout.
    pumpFrame(phase: EnginePhase.compositingBits);

    expect(
      editable,
      // Draw no cursor by default.
      paintsExactlyCountTimes(#drawRect, 0),
    );

    editable.showCursor = showCursor;
    pumpFrame(phase: EnginePhase.compositingBits);

    expect(editable, paints..rect(
      color: const Color.fromARGB(0xFF, 0xFF, 0x00, 0x00),
      rect: const Rect.fromLTWH(40, 0, 1, 10),
    ));

    // Now change to a rounded caret.
    editable.cursorColor = const Color.fromARGB(0xFF, 0x00, 0x00, 0xFF);
    editable.cursorWidth = 4;
    editable.cursorRadius = const Radius.circular(3);
    pumpFrame(phase: EnginePhase.compositingBits);

    expect(editable, paints..rrect(
      color: const Color.fromARGB(0xFF, 0x00, 0x00, 0xFF),
      rrect: RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, 0, 4, 10),
        const Radius.circular(3),
      ),
    ));

    editable.textScaleFactor = 2;
    pumpFrame(phase: EnginePhase.compositingBits);

    // Now the caret height is much bigger due to the bigger font scale.
    expect(editable, paints..rrect(
      color: const Color.fromARGB(0xFF, 0x00, 0x00, 0xFF),
      rrect: RRect.fromRectAndRadius(
        const Rect.fromLTWH(80, 0, 4, 20),
        const Radius.circular(3),
      ),
    ));

    // Can turn off caret.
    showCursor.value = false;
    pumpFrame(phase: EnginePhase.compositingBits);

    expect(editable, paintsExactlyCountTimes(#drawRRect, 0));
  });

  test('Can change textAlign', () {
    final TextSelectionDelegate delegate = _FakeEditableTextState();

    final RenderEditable editable = RenderEditable(
      textDirection: TextDirection.ltr,
      offset: ViewportOffset.zero(),
      textSelectionDelegate: delegate,
      text: const TextSpan(text: 'test'),
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
    );

    layout(editable);

    editable.layout(BoxConstraints.loose(const Size(100, 100)));
    expect(editable.textAlign, TextAlign.start);
    expect(editable.debugNeedsLayout, isFalse);

    editable.textAlign = TextAlign.center;
    expect(editable.textAlign, TextAlign.center);
    expect(editable.debugNeedsLayout, isTrue);
  });

  test('Cursor with ideographic script', () {
    final TextSelectionDelegate delegate = _FakeEditableTextState();
    final ValueNotifier<bool> showCursor = ValueNotifier<bool>(true);
    EditableText.debugDeterministicCursor = true;

    final RenderEditable editable = RenderEditable(
      backgroundCursorColor: Colors.grey,
      textDirection: TextDirection.ltr,
      cursorColor: const Color.fromARGB(0xFF, 0xFF, 0x00, 0x00),
      offset: ViewportOffset.zero(),
      textSelectionDelegate: delegate,
      text: const TextSpan(
        text: '中文测试文本是否正确',
        style: TextStyle(
          height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
        ),
      ),
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      selection: const TextSelection.collapsed(
        offset: 4,
        affinity: TextAffinity.upstream,
      ),
    );

    layout(editable, constraints: BoxConstraints.loose(const Size(100, 100)));
    pumpFrame(phase: EnginePhase.compositingBits);
    expect(
      editable,
      // Draw no cursor by default.
      paintsExactlyCountTimes(#drawRect, 0),
    );

    editable.showCursor = showCursor;
    pumpFrame(phase: EnginePhase.compositingBits);

    expect(editable, paints..rect(
      color: const Color.fromARGB(0xFF, 0xFF, 0x00, 0x00),
      rect: const Rect.fromLTWH(40, 0, 1, 10),
    ));

    // Now change to a rounded caret.
    editable.cursorColor = const Color.fromARGB(0xFF, 0x00, 0x00, 0xFF);
    editable.cursorWidth = 4;
    editable.cursorRadius = const Radius.circular(3);
    pumpFrame(phase: EnginePhase.compositingBits);

    expect(editable, paints..rrect(
      color: const Color.fromARGB(0xFF, 0x00, 0x00, 0xFF),
      rrect: RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, 0, 4, 10),
        const Radius.circular(3),
      ),
    ));

    editable.textScaleFactor = 2;
    pumpFrame(phase: EnginePhase.compositingBits);

    // Now the caret height is much bigger due to the bigger font scale.
    expect(editable, paints..rrect(
      color: const Color.fromARGB(0xFF, 0x00, 0x00, 0xFF),
      rrect: RRect.fromRectAndRadius(
        const Rect.fromLTWH(80, 0, 4, 20),
        const Radius.circular(3),
      ),
    ));

    // Can turn off caret.
    showCursor.value = false;
    pumpFrame(phase: EnginePhase.compositingBits);

    expect(editable, paintsExactlyCountTimes(#drawRRect, 0));

    // TODO(yjbanov): ahem.ttf doesn't have Chinese glyphs, making this test
    //                sensitive to browser/OS when running in web mode:
  }, skip: kIsWeb); // https://github.com/flutter/flutter/issues/83129

  test('text is painted above selection', () {
    final TextSelectionDelegate delegate = _FakeEditableTextState();
    final RenderEditable editable = RenderEditable(
      backgroundCursorColor: Colors.grey,
      selectionColor: Colors.black,
      textDirection: TextDirection.ltr,
      cursorColor: Colors.red,
      offset: ViewportOffset.zero(),
      textSelectionDelegate: delegate,
      text: const TextSpan(
        text: 'test',
        style: TextStyle(
          height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
        ),
      ),
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      selection: const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
        affinity: TextAffinity.upstream,
      ),
    );

    layout(editable);

    expect(
      editable,
      paints
        // Check that it's the black selection box, not the red cursor.
        ..rect(color: Colors.black)
        ..paragraph(),
    );

    // There is exactly one rect paint (1 selection, 0 cursor).
    expect(editable, paintsExactlyCountTimes(#drawRect, 1));
  });

  test('cursor can paint above or below the text', () {
    final TextSelectionDelegate delegate = _FakeEditableTextState();
    final ValueNotifier<bool> showCursor = ValueNotifier<bool>(true);
    final RenderEditable editable = RenderEditable(
      backgroundCursorColor: Colors.grey,
      selectionColor: Colors.black,
      paintCursorAboveText: true,
      textDirection: TextDirection.ltr,
      cursorColor: Colors.red,
      showCursor: showCursor,
      offset: ViewportOffset.zero(),
      textSelectionDelegate: delegate,
      text: const TextSpan(
        text: 'test',
        style: TextStyle(
          height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
        ),
      ),
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      selection: const TextSelection.collapsed(
        offset: 2,
        affinity: TextAffinity.upstream,
      ),
    );

    layout(editable);

    expect(
      editable,
      paints
        ..paragraph()
        // Red collapsed cursor is painted, not a selection box.
        ..rect(color: Colors.red[500]),
    );

    // There is exactly one rect paint (0 selection, 1 cursor).
    expect(editable, paintsExactlyCountTimes(#drawRect, 1));

    editable.paintCursorAboveText = false;
    pumpFrame(phase: EnginePhase.compositingBits);

    expect(
      editable,
      // The paint order is now flipped.
      paints
        ..rect(color: Colors.red[500])
        ..paragraph(),
    );
    expect(editable, paintsExactlyCountTimes(#drawRect, 1));
  });

  test('selects correct place with offsets', () {
    const String text = 'test\ntest';
    final _FakeEditableTextState delegate = _FakeEditableTextState()
      ..textEditingValue = const TextEditingValue(text: text);
    final ViewportOffset viewportOffset = ViewportOffset.zero();
    final RenderEditable editable = RenderEditable(
      backgroundCursorColor: Colors.grey,
      selectionColor: Colors.black,
      textDirection: TextDirection.ltr,
      cursorColor: Colors.red,
      offset: viewportOffset,
      // This makes the scroll axis vertical.
      maxLines: 2,
      textSelectionDelegate: delegate,
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      text: const TextSpan(
        text: text,
        style: TextStyle(
          height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
        ),
      ),
      selection: const TextSelection.collapsed(
        offset: 4,
      ),
    );

    layout(editable);

    expect(
      editable,
      paints..paragraph(offset: Offset.zero),
    );

    editable.selectPositionAt(from: const Offset(0, 2), cause: SelectionChangedCause.tap);
    pumpFrame();
    expect(delegate.selection!.isCollapsed, true);
    expect(delegate.selection!.baseOffset, 0);

    viewportOffset.correctBy(10);

    pumpFrame(phase: EnginePhase.compositingBits);

    expect(
      editable,
      paints..paragraph(offset: const Offset(0, -10)),
    );

    // Tap the same place. But because the offset is scrolled up, the second line
    // gets tapped instead.
    editable.selectPositionAt(from: const Offset(0, 2), cause: SelectionChangedCause.tap);
    pumpFrame();

    expect(delegate.selection!.isCollapsed, true);
    expect(delegate.selection!.baseOffset, 5);

    // Test the other selection methods.
    // Move over by one character.
    editable.handleTapDown(TapDownDetails(globalPosition: const Offset(10, 2)));
    pumpFrame();
    editable.selectPosition(cause:SelectionChangedCause.tap);
    pumpFrame();
    expect(delegate.selection!.isCollapsed, true);
    expect(delegate.selection!.baseOffset, 6);

    editable.handleTapDown(TapDownDetails(globalPosition: const Offset(20, 2)));
    pumpFrame();
    editable.selectWord(cause:SelectionChangedCause.longPress);
    pumpFrame();
    expect(delegate.selection!.isCollapsed, false);
    expect(delegate.selection!.baseOffset, 5);
    expect(delegate.selection!.extentOffset, 9);

    // Select one more character down but since it's still part of the same
    // word, the same word is selected.
    editable.selectWordsInRange(from: const Offset(30, 2), cause:SelectionChangedCause.longPress);
    pumpFrame();
    expect(delegate.selection!.isCollapsed, false);
    expect(delegate.selection!.baseOffset, 5);
    expect(delegate.selection!.extentOffset, 9);
  });

  test('selects readonly renderEditable matches native behavior for android', () {
    // Regression test for https://github.com/flutter/flutter/issues/79166.
    final TargetPlatform? previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const String text = '  test';
    final _FakeEditableTextState delegate = _FakeEditableTextState()
      ..textEditingValue = const TextEditingValue(text: text);
    final ViewportOffset viewportOffset = ViewportOffset.zero();
    final RenderEditable editable = RenderEditable(
      backgroundCursorColor: Colors.grey,
      selectionColor: Colors.black,
      textDirection: TextDirection.ltr,
      cursorColor: Colors.red,
      readOnly: true,
      offset: viewportOffset,
      textSelectionDelegate: delegate,
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      text: const TextSpan(
        text: text,
        style: TextStyle(
          height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
        ),
      ),
      selection: const TextSelection.collapsed(
        offset: 4,
      ),
    );

    layout(editable);

    // Select the second white space, where the text position = 1.
    editable.selectWordsInRange(from: const Offset(10, 2), cause:SelectionChangedCause.longPress);
    pumpFrame();
    expect(delegate.selection!.isCollapsed, false);
    expect(delegate.selection!.baseOffset, 1);
    expect(delegate.selection!.extentOffset, 2);
    debugDefaultTargetPlatformOverride = previousPlatform;
  });

  test('selects renderEditable matches native behavior for iOS case 1', () {
    // Regression test for https://github.com/flutter/flutter/issues/79166.
    final TargetPlatform? previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const String text = '  test';
    final _FakeEditableTextState delegate = _FakeEditableTextState()
      ..textEditingValue = const TextEditingValue(text: text);
    final ViewportOffset viewportOffset = ViewportOffset.zero();
    final RenderEditable editable = RenderEditable(
      backgroundCursorColor: Colors.grey,
      selectionColor: Colors.black,
      textDirection: TextDirection.ltr,
      cursorColor: Colors.red,
      offset: viewportOffset,
      textSelectionDelegate: delegate,
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      text: const TextSpan(
        text: text,
        style: TextStyle(
          height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
        ),
      ),
      selection: const TextSelection.collapsed(
        offset: 4,
      ),
    );

    layout(editable);

    // Select the second white space, where the text position = 1.
    editable.selectWordsInRange(from: const Offset(10, 2), cause:SelectionChangedCause.longPress);
    pumpFrame();
    expect(delegate.selection!.isCollapsed, false);
    expect(delegate.selection!.baseOffset, 1);
    expect(delegate.selection!.extentOffset, 6);
    debugDefaultTargetPlatformOverride = previousPlatform;
  });

  test('selects renderEditable matches native behavior for iOS case 2', () {
    // Regression test for https://github.com/flutter/flutter/issues/79166.
    final TargetPlatform? previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const String text = '   ';
    final _FakeEditableTextState delegate = _FakeEditableTextState()
      ..textEditingValue = const TextEditingValue(text: text);
    final ViewportOffset viewportOffset = ViewportOffset.zero();
    final RenderEditable editable = RenderEditable(
      backgroundCursorColor: Colors.grey,
      selectionColor: Colors.black,
      textDirection: TextDirection.ltr,
      cursorColor: Colors.red,
      offset: viewportOffset,
      textSelectionDelegate: delegate,
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      text: const TextSpan(
        text: text,
        style: TextStyle(
          height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
        ),
      ),
      selection: const TextSelection.collapsed(
        offset: 4,
      ),
    );

    layout(editable);

    // Select the second white space, where the text position = 1.
    editable.selectWordsInRange(from: const Offset(10, 2), cause:SelectionChangedCause.longPress);
    pumpFrame();
    expect(delegate.selection!.isCollapsed, true);
    expect(delegate.selection!.baseOffset, 1);
    expect(delegate.selection!.extentOffset, 1);
    debugDefaultTargetPlatformOverride = previousPlatform;
  });

  test('selects correct place when offsets are flipped', () {
    const String text = 'abc def ghi';
    final _FakeEditableTextState delegate = _FakeEditableTextState()
      ..textEditingValue = const TextEditingValue(text: text);
    final ViewportOffset viewportOffset = ViewportOffset.zero();
    final RenderEditable editable = RenderEditable(
      backgroundCursorColor: Colors.grey,
      selectionColor: Colors.black,
      textDirection: TextDirection.ltr,
      cursorColor: Colors.red,
      offset: viewportOffset,
      textSelectionDelegate: delegate,
      text: const TextSpan(
        text: text,
        style: TextStyle(
          height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
        ),
      ),
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
    );

    layout(editable);

    editable.selectPositionAt(from: const Offset(30, 2), to: const Offset(10, 2), cause: SelectionChangedCause.drag);
    pumpFrame();
    expect(delegate.selection!.isCollapsed, isFalse);
    expect(delegate.selection!.baseOffset, 3);
    expect(delegate.selection!.extentOffset, 1);
  });

  test('promptRect disappears when promptRectColor is set to null', () {
    const Color promptRectColor = Color(0x12345678);
    final TextSelectionDelegate delegate = _FakeEditableTextState();
    final RenderEditable editable = RenderEditable(
      text: const TextSpan(
        style: TextStyle(height: 1.0, fontSize: 10.0, fontFamily: 'Ahem'),
        text: 'ABCDEFG',
      ),
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      textDirection: TextDirection.ltr,
      locale: const Locale('en', 'US'),
      offset: ViewportOffset.fixed(10.0),
      textSelectionDelegate: delegate,
      selection: const TextSelection.collapsed(offset: 0),
      promptRectColor: promptRectColor,
      promptRectRange: const TextRange(start: 0, end: 1),
    );

    layout(editable, constraints: BoxConstraints.loose(const Size(1000.0, 1000.0)));
    pumpFrame(phase: EnginePhase.compositingBits);

    expect(
      (Canvas canvas) => editable.paint(TestRecordingPaintingContext(canvas), Offset.zero),
      paints..rect(color: promptRectColor),
    );

    editable.promptRectColor = null;

    editable.layout(BoxConstraints.loose(const Size(1000.0, 1000.0)));
    pumpFrame(phase: EnginePhase.compositingBits);

    expect(editable.promptRectColor, null);
    expect(
      (Canvas canvas) => editable.paint(TestRecordingPaintingContext(canvas), Offset.zero),
      isNot(paints..rect(color: promptRectColor)),
    );
  });

  test('editable hasFocus correctly initialized', () {
    // Regression test for https://github.com/flutter/flutter/issues/21640
    final TextSelectionDelegate delegate = _FakeEditableTextState();
    final RenderEditable editable = RenderEditable(
      text: const TextSpan(
        style: TextStyle(height: 1.0, fontSize: 10.0, fontFamily: 'Ahem'),
        text: '12345',
      ),
      textDirection: TextDirection.ltr,
      locale: const Locale('en', 'US'),
      offset: ViewportOffset.zero(),
      textSelectionDelegate: delegate,
      hasFocus: true,
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
    );

    expect(editable.hasFocus, true);
    editable.hasFocus = false;
    expect(editable.hasFocus, false);
  });

  test('has correct maxScrollExtent', () {
    final TextSelectionDelegate delegate = _FakeEditableTextState();
    EditableText.debugDeterministicCursor = true;

    final RenderEditable editable = RenderEditable(
      maxLines: 2,
      backgroundCursorColor: Colors.grey,
      textDirection: TextDirection.ltr,
      cursorColor: const Color.fromARGB(0xFF, 0xFF, 0x00, 0x00),
      offset: ViewportOffset.zero(),
      textSelectionDelegate: delegate,
      text: const TextSpan(
        text: '撒地方加咖啡哈金凤凰卡号方式剪坏算法发挥福建垃\nasfjafjajfjaslfjaskjflasjfksajf撒分开建安路口附近拉设\n计费可使肌肤撒附近埃里克圾房卡设计费"',
        style: TextStyle(
          height: 1.0, fontSize: 10.0, fontFamily: 'Roboto',
        ),
      ),
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      selection: const TextSelection.collapsed(
        offset: 4,
        affinity: TextAffinity.upstream,
      ),
    );

    editable.layout(BoxConstraints.loose(const Size(100.0, 1000.0)));
    expect(editable.size, equals(const Size(100, 20)));
    expect(editable.maxLines, equals(2));
    expect(editable.maxScrollExtent, equals(90));

    editable.layout(BoxConstraints.loose(const Size(150.0, 1000.0)));
    expect(editable.maxScrollExtent, equals(50));

    editable.layout(BoxConstraints.loose(const Size(200.0, 1000.0)));
    expect(editable.maxScrollExtent, equals(40));

    editable.layout(BoxConstraints.loose(const Size(500.0, 1000.0)));
    expect(editable.maxScrollExtent, equals(10));

    editable.layout(BoxConstraints.loose(const Size(1000.0, 1000.0)));
    expect(editable.maxScrollExtent, equals(10));
    // TODO(yjbanov): This test is failing in the Dart HHH-web bot and
    //                needs additional investigation before it can be reenabled.
  }, skip: const bool.fromEnvironment('DART_HHH_BOT')); // https://github.com/flutter/flutter/issues/93691

  test('getEndpointsForSelection handles empty characters', () {
    final TextSelectionDelegate delegate = _FakeEditableTextState();
    final RenderEditable editable = RenderEditable(
      // This is a Unicode left-to-right mark character that will not render
      // any glyphs.
      text: const TextSpan(text: '\u200e'),
      textDirection: TextDirection.ltr,
      offset: ViewportOffset.zero(),
      textSelectionDelegate: delegate,
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
    );
    editable.layout(BoxConstraints.loose(const Size(100, 100)));
    final List<TextSelectionPoint> endpoints = editable.getEndpointsForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 1),
    );
    expect(endpoints[0].point.dx, 0);
  });

  group('getRectForComposingRange', () {
    const TextSpan emptyTextSpan = TextSpan(text: '\u200e');
    final TextSelectionDelegate delegate = _FakeEditableTextState();
    final RenderEditable editable = RenderEditable(
      maxLines: null,
      textDirection: TextDirection.ltr,
      offset: ViewportOffset.zero(),
      textSelectionDelegate: delegate,
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
    );

    test('returns null when no composing range', () {
      editable.text = const TextSpan(text: '123');
      editable.layout(const BoxConstraints.tightFor(width: 200));

      // Invalid range.
      expect(editable.getRectForComposingRange(const TextRange(start: -1, end: 2)), isNull);
      // Collapsed range.
      expect(editable.getRectForComposingRange(const TextRange.collapsed(2)), isNull);

      // Empty Editable.
      editable.text = emptyTextSpan;
      editable.layout(const BoxConstraints.tightFor(width: 200));

      expect(
        editable.getRectForComposingRange(const TextRange(start: 0, end: 1)),
        // On web this evaluates to a zero-width Rect.
        anyOf(isNull, (Rect rect) => rect.width == 0),
      );
    });

    test('more than 1 run on the same line', () {
      const TextStyle tinyText = TextStyle(fontSize: 1, fontFamily: 'Ahem');
      const TextStyle normalText = TextStyle(fontSize: 10, fontFamily: 'Ahem');
      editable.text = TextSpan(
        children: <TextSpan>[
          const TextSpan(text: 'A', style: tinyText),
          TextSpan(text: 'A' * 20, style: normalText),
          const TextSpan(text: 'A', style: tinyText),
        ],
      );
      // Give it a width that forces the editable to wrap.
      editable.layout(const BoxConstraints.tightFor(width: 200));

      final Rect composingRect = editable.getRectForComposingRange(const TextRange(start: 0, end: 20 + 2))!;

      // Since the range covers an entire line, the Rect should also be almost
      // as wide as the entire paragraph (give or take 1 character).
      expect(composingRect.width, greaterThan(200 - 10));
    });
  });

  group('custom painters', () {
    final TextSelectionDelegate delegate = _FakeEditableTextState();

    final _TestRenderEditable editable = _TestRenderEditable(
      textDirection: TextDirection.ltr,
      offset: ViewportOffset.zero(),
      textSelectionDelegate: delegate,
      text: const TextSpan(
        text: 'test',
        style: TextStyle(
          height: 1.0,
          fontSize: 10.0,
          fontFamily: 'Ahem',
        ),
      ),
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      selection: const TextSelection.collapsed(
        offset: 4,
        affinity: TextAffinity.upstream,
      ),
    );

    setUp(() { EditableText.debugDeterministicCursor = true; });
    tearDown(() {
      EditableText.debugDeterministicCursor = false;
      _TestRenderEditablePainter.paintHistory.clear();
      editable.foregroundPainter = null;
      editable.painter = null;
      editable.paintCount = 0;

      final AbstractNode? parent = editable.parent;
      if (parent is RenderConstrainedBox) {
        parent.child = null;
      }
    });

    test('paints in the correct order', () {
      layout(editable, constraints: BoxConstraints.loose(const Size(100, 100)));
      // Prepare for painting after layout.

      // Foreground painter.
      editable.foregroundPainter = _TestRenderEditablePainter();
      pumpFrame(phase: EnginePhase.compositingBits);

      expect(
        (Canvas canvas) => editable.paint(TestRecordingPaintingContext(canvas), Offset.zero),
        paints
          ..paragraph()
          ..rect(rect: const Rect.fromLTRB(1, 1, 1, 1), color: const Color(0x12345678)),
      );

      // Background painter.
      editable.foregroundPainter = null;
      editable.painter = _TestRenderEditablePainter();

      expect(
        (Canvas canvas) => editable.paint(TestRecordingPaintingContext(canvas), Offset.zero),
        paints
          ..rect(rect: const Rect.fromLTRB(1, 1, 1, 1), color: const Color(0x12345678))
          ..paragraph(),
      );

      editable.foregroundPainter = _TestRenderEditablePainter();
      editable.painter = _TestRenderEditablePainter();

      expect(
        (Canvas canvas) => editable.paint(TestRecordingPaintingContext(canvas), Offset.zero),
        paints
          ..rect(rect: const Rect.fromLTRB(1, 1, 1, 1), color: const Color(0x12345678))
          ..paragraph()
          ..rect(rect: const Rect.fromLTRB(1, 1, 1, 1), color: const Color(0x12345678)),
      );
    });

    test('changing foreground painter', () {
      layout(editable, constraints: BoxConstraints.loose(const Size(100, 100)));
      // Prepare for painting after layout.

      _TestRenderEditablePainter currentPainter = _TestRenderEditablePainter();
      // Foreground painter.
      editable.foregroundPainter = currentPainter;
      pumpFrame(phase: EnginePhase.paint);
      expect(currentPainter.paintCount, 1);

      editable.foregroundPainter = (currentPainter = _TestRenderEditablePainter()..repaint = false);
      pumpFrame(phase: EnginePhase.paint);
      expect(currentPainter.paintCount, 0);

      editable.foregroundPainter = (currentPainter = _TestRenderEditablePainter()..repaint = true);
      pumpFrame(phase: EnginePhase.paint);
      expect(currentPainter.paintCount, 1);
    });

    test('changing background painter', () {
      layout(editable, constraints: BoxConstraints.loose(const Size(100, 100)));
      // Prepare for painting after layout.

      _TestRenderEditablePainter currentPainter = _TestRenderEditablePainter();
      // Foreground painter.
      editable.painter = currentPainter;
      pumpFrame(phase: EnginePhase.paint);
      expect(currentPainter.paintCount, 1);

      editable.painter = (currentPainter = _TestRenderEditablePainter()..repaint = false);
      pumpFrame(phase: EnginePhase.paint);
      expect(currentPainter.paintCount, 0);

      editable.painter = (currentPainter = _TestRenderEditablePainter()..repaint = true);
      pumpFrame(phase: EnginePhase.paint);
      expect(currentPainter.paintCount, 1);
    });

    test('swapping painters', () {
      layout(editable, constraints: BoxConstraints.loose(const Size(100, 100)));

      final _TestRenderEditablePainter painter1 = _TestRenderEditablePainter();
      final _TestRenderEditablePainter painter2 = _TestRenderEditablePainter();

      editable.painter = painter1;
      editable.foregroundPainter = painter2;
      pumpFrame(phase: EnginePhase.paint);
      expect(
        _TestRenderEditablePainter.paintHistory,
        <_TestRenderEditablePainter>[painter1, painter2],
      );

      _TestRenderEditablePainter.paintHistory.clear();
      editable.painter = painter2;
      editable.foregroundPainter = painter1;
      pumpFrame(phase: EnginePhase.paint);
      expect(
        _TestRenderEditablePainter.paintHistory,
        <_TestRenderEditablePainter>[painter2, painter1],
      );
    });

    test('reusing the same painter', () {
      layout(editable, constraints: BoxConstraints.loose(const Size(100, 100)));

      final _TestRenderEditablePainter painter = _TestRenderEditablePainter();
      FlutterErrorDetails? errorDetails;
      editable.painter = painter;
      editable.foregroundPainter = painter;
      pumpFrame(phase: EnginePhase.paint, onErrors: () {
        errorDetails = TestRenderingFlutterBinding.instance.takeFlutterErrorDetails();
      });
      expect(errorDetails, isNull);

      expect(
        _TestRenderEditablePainter.paintHistory,
        <_TestRenderEditablePainter>[painter, painter],
      );
      expect(
        (Canvas canvas) => editable.paint(TestRecordingPaintingContext(canvas), Offset.zero),
        paints
          ..rect(rect: const Rect.fromLTRB(1, 1, 1, 1), color: const Color(0x12345678))
          ..paragraph()
          ..rect(rect: const Rect.fromLTRB(1, 1, 1, 1), color: const Color(0x12345678)),
      );
    });
    test('does not repaint the render editable when custom painters need repaint', () {
      layout(editable, constraints: BoxConstraints.loose(const Size(100, 100)));

      final _TestRenderEditablePainter painter = _TestRenderEditablePainter();
      editable.painter = painter;
      pumpFrame(phase: EnginePhase.paint);
      editable.paintCount = 0;
      painter.paintCount = 0;

      painter.markNeedsPaint();

      pumpFrame(phase: EnginePhase.paint);
      expect(editable.paintCount, 0);
      expect(painter.paintCount, 1);
    });

    test('repaints when its RenderEditable repaints', () {
      layout(editable, constraints: BoxConstraints.loose(const Size(100, 100)));

      final _TestRenderEditablePainter painter = _TestRenderEditablePainter();
      editable.painter = painter;
      pumpFrame(phase: EnginePhase.paint);
      editable.paintCount = 0;
      painter.paintCount = 0;

      editable.markNeedsPaint();

      pumpFrame(phase: EnginePhase.paint);
      expect(editable.paintCount, 1);
      expect(painter.paintCount, 1);
    });

    test('correct coordinate space', () {
      layout(editable, constraints: BoxConstraints.loose(const Size(100, 100)));

      final _TestRenderEditablePainter painter = _TestRenderEditablePainter();
      editable.painter = painter;
      editable.offset = ViewportOffset.fixed(1000);

      pumpFrame(phase: EnginePhase.compositingBits);
      expect(
        (Canvas canvas) => editable.paint(TestRecordingPaintingContext(canvas), Offset.zero),
        paints
          ..rect(rect: const Rect.fromLTRB(1, 1, 1, 1), color: const Color(0x12345678))
          ..paragraph(),
      );
    });

    group('hit testing', () {
      test('hits correct TextSpan when not scrolled', () {
        final TextSelectionDelegate delegate = _FakeEditableTextState();
        final RenderEditable editable = RenderEditable(
          text: const TextSpan(
            style: TextStyle(height: 1.0, fontSize: 10.0, fontFamily: 'Ahem'),
            children: <InlineSpan>[
              TextSpan(text: 'A'),
              TextSpan(text: 'B'),
            ],
          ),
          startHandleLayerLink: LayerLink(),
          endHandleLayerLink: LayerLink(),
          textDirection: TextDirection.ltr,
          offset: ViewportOffset.fixed(0.0),
          textSelectionDelegate: delegate,
          selection: const TextSelection.collapsed(
            offset: 0,
          ),
        );
        layout(editable, constraints: BoxConstraints.loose(const Size(500.0, 500.0)));
        // Prepare for painting after layout.
        pumpFrame(phase: EnginePhase.compositingBits);

        BoxHitTestResult result = BoxHitTestResult();
        editable.hitTest(result, position: Offset.zero);
        // We expect two hit test entries in the path because the RenderEditable
        // will add itself as well.
        expect(result.path, hasLength(2));
        HitTestTarget target = result.path.first.target;
        expect(target, isA<TextSpan>());
        expect((target as TextSpan).text, 'A');
        // Only testing the RenderEditable entry here once, not anymore below.
        expect(result.path.last.target, isA<RenderEditable>());

        result = BoxHitTestResult();
        editable.hitTest(result, position: const Offset(15.0, 0.0));
        expect(result.path, hasLength(2));
        target = result.path.first.target;
        expect(target, isA<TextSpan>());
        expect((target as TextSpan).text, 'B');
      });

      test('hits correct TextSpan when scrolled vertically', () {
        final TextSelectionDelegate delegate = _FakeEditableTextState();
        final RenderEditable editable = RenderEditable(
          text: const TextSpan(
            style: TextStyle(height: 1.0, fontSize: 10.0, fontFamily: 'Ahem'),
            children: <InlineSpan>[
              TextSpan(text: 'A'),
              TextSpan(text: 'B\n'),
              TextSpan(text: 'C'),
            ],
          ),
          startHandleLayerLink: LayerLink(),
          endHandleLayerLink: LayerLink(),
          textDirection: TextDirection.ltr,
          // Given maxLines of null and an offset of 5, the editable will be
          // scrolled vertically by 5 pixels.
          maxLines: null,
          offset: ViewportOffset.fixed(5.0),
          textSelectionDelegate: delegate,
          selection: const TextSelection.collapsed(
            offset: 0,
          ),
        );
        layout(editable, constraints: BoxConstraints.loose(const Size(500.0, 500.0)));
        // Prepare for painting after layout.
        pumpFrame(phase: EnginePhase.compositingBits);

        BoxHitTestResult result = BoxHitTestResult();
        editable.hitTest(result, position: Offset.zero);
        expect(result.path, hasLength(2));
        HitTestTarget target = result.path.first.target;
        expect(target, isA<TextSpan>());
        expect((target as TextSpan).text, 'A');

        result = BoxHitTestResult();
        editable.hitTest(result, position: const Offset(15.0, 0.0));
        expect(result.path, hasLength(2));
        target = result.path.first.target;
        expect(target, isA<TextSpan>());
        expect((target as TextSpan).text, 'B\n');

        result = BoxHitTestResult();
        // When we hit at y=6 and are scrolled by -5 vertically, we expect "C"
        // to be hit because the font size is 10.
        editable.hitTest(result, position: const Offset(0.0, 6.0));
        expect(result.path, hasLength(2));
        target = result.path.first.target;
        expect(target, isA<TextSpan>());
        expect((target as TextSpan).text, 'C');
      });

      test('hits correct TextSpan when scrolled horizontally', () {
        final TextSelectionDelegate delegate = _FakeEditableTextState();
        final RenderEditable editable = RenderEditable(
          text: const TextSpan(
            style: TextStyle(height: 1.0, fontSize: 10.0, fontFamily: 'Ahem'),
            children: <InlineSpan>[
              TextSpan(text: 'A'),
              TextSpan(text: 'B'),
            ],
          ),
          startHandleLayerLink: LayerLink(),
          endHandleLayerLink: LayerLink(),
          textDirection: TextDirection.ltr,
          // Given maxLines of 1 and an offset of 5, the editable will be
          // scrolled by 5 pixels to the left.
          offset: ViewportOffset.fixed(5.0),
          textSelectionDelegate: delegate,
          selection: const TextSelection.collapsed(
            offset: 0,
          ),
        );
        layout(editable, constraints: BoxConstraints.loose(const Size(500.0, 500.0)));
        // Prepare for painting after layout.
        pumpFrame(phase: EnginePhase.compositingBits);

        final BoxHitTestResult result = BoxHitTestResult();
        // At x=6, we should hit "B" as we are scrolled to the left by 6
        // pixels.
        editable.hitTest(result, position: const Offset(6.0, 0));
        expect(result.path, hasLength(2));
        final HitTestTarget target = result.path.first.target;
        expect(target, isA<TextSpan>());
        expect((target as TextSpan).text, 'B');
      });
    });
  });

  group('WidgetSpan support', () {
    test('able to render basic WidgetSpan', () async {
      final TextSelectionDelegate delegate = _FakeEditableTextState()
        ..textEditingValue = const TextEditingValue(
            text: 'test',
            selection: TextSelection.collapsed(offset: 3),
          );
      final List<RenderBox> renderBoxes = <RenderBox>[
        RenderParagraph(const TextSpan(text: 'b'), textDirection: TextDirection.ltr),
      ];
      final ViewportOffset viewportOffset = ViewportOffset.zero();
      final RenderEditable editable = RenderEditable(
        backgroundCursorColor: Colors.grey,
        selectionColor: Colors.black,
        textDirection: TextDirection.ltr,
        cursorColor: Colors.red,
        offset: viewportOffset,
        textSelectionDelegate: delegate,
        startHandleLayerLink: LayerLink(),
        endHandleLayerLink: LayerLink(),
        text: TextSpan(
          style: const TextStyle(
            height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
          ),
          children: <InlineSpan>[
            const TextSpan(text: 'test'),
            WidgetSpan(child: Container(width: 10, height: 10, color: Colors.blue)),
          ],
        ),
        selection: const TextSelection.collapsed(offset: 3),
        children: renderBoxes,
      );

      layout(editable);
      editable.hasFocus = true;
      pumpFrame();

      final Rect composingRect = editable.getRectForComposingRange(const TextRange(start: 4, end: 5))!;
      expect(composingRect, const Rect.fromLTRB(40.0, 0.0, 54.0, 14.0));
    }, skip: isBrowser); // https://github.com/flutter/flutter/issues/61021

    test('able to render multiple WidgetSpans', () async {
      final TextSelectionDelegate delegate = _FakeEditableTextState()
        ..textEditingValue = const TextEditingValue(
            text: 'test',
            selection: TextSelection.collapsed(offset: 3),
          );
      final List<RenderBox> renderBoxes = <RenderBox>[
        RenderParagraph(const TextSpan(text: 'b'), textDirection: TextDirection.ltr),
        RenderParagraph(const TextSpan(text: 'c'), textDirection: TextDirection.ltr),
        RenderParagraph(const TextSpan(text: 'd'), textDirection: TextDirection.ltr),
      ];
      final ViewportOffset viewportOffset = ViewportOffset.zero();
      final RenderEditable editable = RenderEditable(
        backgroundCursorColor: Colors.grey,
        selectionColor: Colors.black,
        textDirection: TextDirection.ltr,
        cursorColor: Colors.red,
        offset: viewportOffset,
        textSelectionDelegate: delegate,
        startHandleLayerLink: LayerLink(),
        endHandleLayerLink: LayerLink(),
        text: TextSpan(
          style: const TextStyle(
            height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
          ),
          children: <InlineSpan>[
            const TextSpan(text: 'test'),
            WidgetSpan(child: Container(width: 10, height: 10, color: Colors.blue)),
            WidgetSpan(child: Container(width: 10, height: 10, color: Colors.blue)),
            WidgetSpan(child: Container(width: 10, height: 10, color: Colors.blue)),
          ],
        ),
        selection: const TextSelection.collapsed(offset: 3),
        children: renderBoxes,
      );

      layout(editable);
      editable.hasFocus = true;
      pumpFrame();

      final Rect composingRect = editable.getRectForComposingRange(const TextRange(start: 4, end: 7))!;
      expect(composingRect, const Rect.fromLTRB(40.0, 0.0, 82.0, 14.0));
    }, skip: isBrowser); // https://github.com/flutter/flutter/issues/61021

    test('able to render WidgetSpans with line wrap', () async {
      final TextSelectionDelegate delegate = _FakeEditableTextState()
        ..textEditingValue = const TextEditingValue(
            text: 'test',
            selection: TextSelection.collapsed(offset: 3),
          );
      final List<RenderBox> renderBoxes = <RenderBox>[
        RenderParagraph(const TextSpan(text: 'b'), textDirection: TextDirection.ltr),
        RenderParagraph(const TextSpan(text: 'c'), textDirection: TextDirection.ltr),
        RenderParagraph(const TextSpan(text: 'd'), textDirection: TextDirection.ltr),
      ];
      final ViewportOffset viewportOffset = ViewportOffset.zero();
      final RenderEditable editable = RenderEditable(
        backgroundCursorColor: Colors.grey,
        selectionColor: Colors.black,
        textDirection: TextDirection.ltr,
        cursorColor: Colors.red,
        offset: viewportOffset,
        textSelectionDelegate: delegate,
        startHandleLayerLink: LayerLink(),
        endHandleLayerLink: LayerLink(),
        text: const TextSpan(
          style: TextStyle(
            height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
          ),
          children: <InlineSpan>[
            TextSpan(text: 'test'),
            WidgetSpan(child: Text('b')),
            WidgetSpan(child: Text('c')),
            WidgetSpan(child: Text('d')),
          ],
        ),
        selection: const TextSelection.collapsed(offset: 3),
        maxLines: 2,
        minLines: 2,
        children: renderBoxes,
      );

      // Force a line wrap
      layout(editable, constraints: const BoxConstraints(maxWidth: 75));
      editable.hasFocus = true;
      pumpFrame();

      Rect composingRect = editable.getRectForComposingRange(const TextRange(start: 4, end: 6))!;
      expect(composingRect, const Rect.fromLTRB(40.0, 0.0, 68.0, 14.0));
      composingRect = editable.getRectForComposingRange(const TextRange(start: 6, end: 7))!;
      expect(composingRect, const Rect.fromLTRB(0.0, 14.0, 14.0, 28.0));
    }, skip: isBrowser); // https://github.com/flutter/flutter/issues/61021

    test('able to render WidgetSpans with line wrap alternating spans', () async {
      final TextSelectionDelegate delegate = _FakeEditableTextState()
        ..textEditingValue = const TextEditingValue(
            text: 'test',
            selection: TextSelection.collapsed(offset: 3),
          );
      final List<RenderBox> renderBoxes = <RenderBox>[
        RenderParagraph(const TextSpan(text: 'b'), textDirection: TextDirection.ltr),
        RenderParagraph(const TextSpan(text: 'c'), textDirection: TextDirection.ltr),
        RenderParagraph(const TextSpan(text: 'd'), textDirection: TextDirection.ltr),
        RenderParagraph(const TextSpan(text: 'e'), textDirection: TextDirection.ltr),
      ];
      final ViewportOffset viewportOffset = ViewportOffset.zero();
      final RenderEditable editable = RenderEditable(
        backgroundCursorColor: Colors.grey,
        selectionColor: Colors.black,
        textDirection: TextDirection.ltr,
        cursorColor: Colors.red,
        offset: viewportOffset,
        textSelectionDelegate: delegate,
        startHandleLayerLink: LayerLink(),
        endHandleLayerLink: LayerLink(),
        text: const TextSpan(
          style: TextStyle(
            height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
          ),
          children: <InlineSpan>[
            TextSpan(text: 'test'),
            WidgetSpan(child: Text('b')),
            WidgetSpan(child: Text('c')),
            WidgetSpan(child: Text('d')),
            TextSpan(text: 'HI'),
            WidgetSpan(child: Text('e')),
          ],
        ),
        selection: const TextSelection.collapsed(offset: 3),
        maxLines: 2,
        minLines: 2,
        children: renderBoxes,
      );

      // Force a line wrap
      layout(editable, constraints: const BoxConstraints(maxWidth: 75));
      editable.hasFocus = true;
      pumpFrame();

      Rect composingRect = editable.getRectForComposingRange(const TextRange(start: 4, end: 6))!;
      expect(composingRect, const Rect.fromLTRB(40.0, 0.0, 68.0, 14.0));
      composingRect = editable.getRectForComposingRange(const TextRange(start: 6, end: 7))!;
      expect(composingRect, const Rect.fromLTRB(0.0, 14.0, 14.0, 28.0));
      composingRect = editable.getRectForComposingRange(const TextRange(start: 7, end: 8))!; // H
      expect(composingRect, const Rect.fromLTRB(14.0, 18.0, 24.0, 28.0));
      composingRect = editable.getRectForComposingRange(const TextRange(start: 8, end: 9))!; // I
      expect(composingRect, const Rect.fromLTRB(24.0, 18.0, 34.0, 28.0));
      composingRect = editable.getRectForComposingRange(const TextRange(start: 9, end: 10))!;
      expect(composingRect, const Rect.fromLTRB(34.0, 14.0, 48.0, 28.0));
    }, skip: isBrowser); // https://github.com/flutter/flutter/issues/61021

    test('able to render WidgetSpans nested spans', () async {
      final TextSelectionDelegate delegate = _FakeEditableTextState()
        ..textEditingValue = const TextEditingValue(
            text: 'test',
            selection: TextSelection.collapsed(offset: 3),
          );
      final List<RenderBox> renderBoxes = <RenderBox>[
        RenderParagraph(const TextSpan(text: 'a'), textDirection: TextDirection.ltr),
        RenderParagraph(const TextSpan(text: 'b'), textDirection: TextDirection.ltr),
        RenderParagraph(const TextSpan(text: 'c'), textDirection: TextDirection.ltr),
      ];
      final ViewportOffset viewportOffset = ViewportOffset.zero();
      final RenderEditable editable = RenderEditable(
        backgroundCursorColor: Colors.grey,
        selectionColor: Colors.black,
        textDirection: TextDirection.ltr,
        cursorColor: Colors.red,
        offset: viewportOffset,
        textSelectionDelegate: delegate,
        startHandleLayerLink: LayerLink(),
        endHandleLayerLink: LayerLink(),
        text: const TextSpan(
          style: TextStyle(
            height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
          ),
          children: <InlineSpan>[
            TextSpan(text: 'test'),
            WidgetSpan(child: Text('a')),
            TextSpan(children: <InlineSpan>[
                WidgetSpan(child: Text('b')),
                WidgetSpan(child: Text('c')),
              ],
            ),
          ],
        ),
        selection: const TextSelection.collapsed(offset: 3),
        maxLines: 2,
        minLines: 2,
        children: renderBoxes,
      );

      // Force a line wrap
      layout(editable, constraints: const BoxConstraints(maxWidth: 75));
      editable.hasFocus = true;
      pumpFrame();

      Rect? composingRect = editable.getRectForComposingRange(const TextRange(start: 4, end: 5));
      expect(composingRect, const Rect.fromLTRB(40.0, 0.0, 54.0, 14.0));
      composingRect = editable.getRectForComposingRange(const TextRange(start: 5, end: 6));
      expect(composingRect, const Rect.fromLTRB(54.0, 0.0, 68.0, 14.0));
      composingRect = editable.getRectForComposingRange(const TextRange(start: 6, end: 7));
      expect(composingRect, const Rect.fromLTRB(0.0, 14.0, 14.0, 28.0));
      composingRect = editable.getRectForComposingRange(const TextRange(start: 7, end: 8));
      expect(composingRect, null);
    }, skip: isBrowser); // https://github.com/flutter/flutter/issues/61021

    test('can compute IntrinsicWidth for WidgetSpans', () {
      // Regression test for https://github.com/flutter/flutter/issues/59316
      const double screenWidth = 1000.0;
      const double fixedHeight = 1000.0;
      const String sentence = 'one two';
      final TextSelectionDelegate delegate = _FakeEditableTextState()
        ..textEditingValue = const TextEditingValue(
            text: 'test',
            selection: TextSelection.collapsed(offset: 3),
          );
      final List<RenderBox> renderBoxes = <RenderBox>[
        RenderParagraph(const TextSpan(text: sentence), textDirection: TextDirection.ltr),
      ];
      final ViewportOffset viewportOffset = ViewportOffset.zero();
      final RenderEditable editable = RenderEditable(
        backgroundCursorColor: Colors.grey,
        selectionColor: Colors.black,
        textDirection: TextDirection.ltr,
        cursorColor: Colors.red,
        offset: viewportOffset,
        textSelectionDelegate: delegate,
        startHandleLayerLink: LayerLink(),
        endHandleLayerLink: LayerLink(),
        text: const TextSpan(
          style: TextStyle(
            height: 1.0, fontSize: 10.0, fontFamily: 'Ahem',
          ),
          children: <InlineSpan>[
            TextSpan(text: 'test'),
            WidgetSpan(child: Text('a')),
          ],
        ),
        selection: const TextSelection.collapsed(offset: 3),
        maxLines: 2,
        minLines: 2,
        textScaleFactor: 2.0,
        children: renderBoxes,
      );
      layout(editable, constraints: const BoxConstraints(maxWidth: screenWidth));
      editable.hasFocus = true;
      final double maxIntrinsicWidth = editable.computeMaxIntrinsicWidth(fixedHeight);
      pumpFrame();

      expect(maxIntrinsicWidth, 278);
    });

    test('hits correct WidgetSpan when not scrolled', () {
      final TextSelectionDelegate delegate = _FakeEditableTextState()
        ..textEditingValue = const TextEditingValue(
            text: 'test',
            selection: TextSelection.collapsed(offset: 3),
          );
      final List<RenderBox> renderBoxes = <RenderBox>[
        RenderParagraph(const TextSpan(text: 'a'), textDirection: TextDirection.ltr),
        RenderParagraph(const TextSpan(text: 'b'), textDirection: TextDirection.ltr),
        RenderParagraph(const TextSpan(text: 'c'), textDirection: TextDirection.ltr),
      ];
      final RenderEditable editable = RenderEditable(
        text: const TextSpan(
          style: TextStyle(height: 1.0, fontSize: 10.0, fontFamily: 'Ahem'),
          children: <InlineSpan>[
            TextSpan(text: 'test'),
            WidgetSpan(child: Text('a')),
            TextSpan(children: <InlineSpan>[
                WidgetSpan(child: Text('b')),
                WidgetSpan(child: Text('c')),
              ],
            ),
          ],
        ),
        startHandleLayerLink: LayerLink(),
        endHandleLayerLink: LayerLink(),
        textDirection: TextDirection.ltr,
        offset: ViewportOffset.fixed(0.0),
        textSelectionDelegate: delegate,
        selection: const TextSelection.collapsed(
          offset: 0,
        ),
        children: renderBoxes,
      );
      layout(editable, constraints: BoxConstraints.loose(const Size(500.0, 500.0)));
      // Prepare for painting after layout.
      pumpFrame(phase: EnginePhase.compositingBits);
      BoxHitTestResult result = BoxHitTestResult();
      editable.hitTest(result, position: Offset.zero);
      // We expect two hit test entries in the path because the RenderEditable
      // will add itself as well.
      expect(result.path, hasLength(2));
      HitTestTarget target = result.path.first.target;
      expect(target, isA<TextSpan>());
      expect((target as TextSpan).text, 'test');
      // Only testing the RenderEditable entry here once, not anymore below.
      expect(result.path.last.target, isA<RenderEditable>());
      result = BoxHitTestResult();
      editable.hitTest(result, position: const Offset(15.0, 0.0));
      expect(result.path, hasLength(2));
      target = result.path.first.target;
      expect(target, isA<TextSpan>());
      expect((target as TextSpan).text, 'test');

      result = BoxHitTestResult();
      editable.hitTest(result, position: const Offset(41.0, 0.0));
      expect(result.path, hasLength(3));
      target = result.path.first.target;
      expect(target, isA<TextSpan>());
      expect((target as TextSpan).text, 'a');

      result = BoxHitTestResult();
      editable.hitTest(result, position: const Offset(55.0, 0.0));
      expect(result.path, hasLength(3));
      target = result.path.first.target;
      expect(target, isA<TextSpan>());
      expect((target as TextSpan).text, 'b');

      result = BoxHitTestResult();
      editable.hitTest(result, position: const Offset(69.0, 5.0));
      expect(result.path, hasLength(3));
      target = result.path.first.target;
      expect(target, isA<TextSpan>());
      expect((target as TextSpan).text, 'c');

      result = BoxHitTestResult();
      editable.hitTest(result, position: const Offset(5.0, 15.0));
      expect(result.path, hasLength(0));
    }, skip: isBrowser); // https://github.com/flutter/flutter/issues/61020
  });

  test('does not skip TextPainter.layout because of invalid cache', () {
    // Regression test for https://github.com/flutter/flutter/issues/84896.
    final TextSelectionDelegate delegate = _FakeEditableTextState();
    const BoxConstraints constraints = BoxConstraints(minWidth: 100, maxWidth: 500);
    final RenderEditable editable = RenderEditable(
      text: const TextSpan(
        style: TextStyle(height: 1.0, fontSize: 10.0, fontFamily: 'Ahem'),
        text: 'A',
      ),
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      textDirection: TextDirection.ltr,
      locale: const Locale('en', 'US'),
      offset: ViewportOffset.fixed(10.0),
      textSelectionDelegate: delegate,
      selection: const TextSelection.collapsed(offset: 0),
      cursorColor: const Color(0xFFFFFFFF),
      showCursor: ValueNotifier<bool>(true),
    );
    layout(editable, constraints: constraints);

    final double initialWidth = editable.computeDryLayout(constraints).width;
    expect(initialWidth, 500);

    // Turn off forceLine. Now the width should be significantly smaller.
    editable.forceLine = false;
    expect(editable.computeDryLayout(constraints).width, lessThan(initialWidth));
  });
}

class _TestRenderEditable extends RenderEditable {
  _TestRenderEditable({
    required super.textDirection,
    required super.offset,
    required super.textSelectionDelegate,
    TextSpan? super.text,
    required super.startHandleLayerLink,
    required super.endHandleLayerLink,
    super.selection,
  });

  int paintCount = 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    paintCount += 1;
  }
}

class _TestRenderEditablePainter extends RenderEditablePainter {
  bool repaint = true;
  int paintCount = 0;
  static final List<_TestRenderEditablePainter> paintHistory = <_TestRenderEditablePainter>[];

  @override
  void paint(Canvas canvas, Size size, RenderEditable renderEditable) {
    paintCount += 1;
    canvas.drawRect(const Rect.fromLTRB(1, 1, 1, 1), Paint()..color = const Color(0x12345678));
    paintHistory.add(this);
  }

  @override
  bool shouldRepaint(RenderEditablePainter? oldDelegate) => repaint;

  void markNeedsPaint() {
    notifyListeners();
  }
}
