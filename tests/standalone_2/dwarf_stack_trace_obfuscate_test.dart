// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// VMOptions=--dwarf-stack-traces --save-debugging-info=dwarf_obfuscate.so --obfuscate

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:vm/dwarf/dwarf.dart';

import 'dwarf_stack_trace_test.dart' as base;

@pragma("vm:prefer-inline")
bar() {
  // Keep the 'throw' and its argument on separate lines.
  throw // force linebreak with dartfmt
      "Hello, Dwarf!";
}

@pragma("vm:never-inline")
foo() {
  bar();
}

Future<void> main() async {
  String rawStack;
  try {
    foo();
  } catch (e, st) {
    rawStack = st.toString();
  }

  if (path.basenameWithoutExtension(Platform.executable) !=
      "dart_precompiled_runtime") {
    return; // Not running from an AOT compiled snapshot.
  }

  if (Platform.isAndroid) {
    return; // Generated dwarf.so not available on the test device.
  }

  final dwarf = Dwarf.fromFile("dwarf_obfuscate.so");

  await base.checkStackTrace(rawStack, dwarf, expectedCallsInfo);
}

final expectedCallsInfo = <List<CallInfo>>[
  // The first frame should correspond to the throw in bar, which was inlined
  // into foo (so we'll get information for two calls for that PC address).
  [
    CallInfo(
        function: "bar",
        filename: "dwarf_stack_trace_obfuscate_test.dart",
        line: 17,
        inlined: true),
    CallInfo(
        function: "foo",
        filename: "dwarf_stack_trace_obfuscate_test.dart",
        line: 23,
        inlined: false)
  ],
  // The second frame corresponds to call to foo in main.
  [
    CallInfo(
        function: "main",
        filename: "dwarf_stack_trace_obfuscate_test.dart",
        line: 29,
        inlined: false)
  ],
  // Don't assume anything about any of the frames below the call to foo
  // in main, as this makes the test too brittle.
];