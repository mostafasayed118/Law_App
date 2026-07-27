import 'package:flutter/material.dart';

abstract interface class LocaleStore {
  Future<Locale?> read();
  Future<void> write(Locale locale);
}

const Set<String> supportedLocaleCodes = <String>{'en', 'ar', 'tr'};
