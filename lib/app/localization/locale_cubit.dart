import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/local/locale_store.dart';

class LocaleState extends Equatable {
  const LocaleState(this.locale);

  final Locale locale;

  @override
  List<Object?> get props => <Object?>[locale.languageCode];
}

class LocaleCubit extends Cubit<LocaleState> {
  LocaleCubit(this._store) : super(const LocaleState(Locale('en')));

  final LocaleStore _store;

  Future<void> load() async {
    final Locale? saved = await _store.read();
    if (saved != null && !isClosed) {
      emit(LocaleState(saved));
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!supportedLocaleCodes.contains(locale.languageCode)) {
      return;
    }
    await _store.write(locale);
    if (!isClosed) {
      emit(LocaleState(locale));
    }
  }
}
