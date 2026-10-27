import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud_sync_service.dart';
import '../database_helper.dart';
import '../tarla_model.dart';
import 'auth_provider.dart';

final fieldsProvider = AsyncNotifierProvider<FieldsNotifier, List<Tarla>>(() {
  return FieldsNotifier();
});

final deletedFieldsProvider = AsyncNotifierProvider<DeletedFieldsNotifier, List<Tarla>>(() {
  return DeletedFieldsNotifier();
});

class FieldsNotifier extends AsyncNotifier<List<Tarla>> {
  Timer? _debounce;

  @override
  Future<List<Tarla>> build() async {
    // Watch authProvider synchronously to automatically rebuild on authentication changes
    ref.watch(authProvider);
    return _fetchFields();
  }

  Future<List<Tarla>> _fetchFields() async {
    final session = ref.read(authProvider).value;
    if (session == null) return [];

    if (session.cloudEnabled && session.familyId != null && session.familyId!.isNotEmpty) {
      // Pull from local DB (already synced at login)
      final tarlalar = await DatabaseHelper.instance.tumTarlalar();
      return tarlalar;
    } else {
      return DatabaseHelper.instance.tumTarlalar();
    }
  }

  Future<void> refreshFields() async {
    // Debounce: ardışık çağrıları 300ms ile birleştir
    _debounce?.cancel();
    final completer = Completer<void>();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() => _fetchFields());
      completer.complete();
    });
    return completer.future;
  }

  Future<void> addField(Tarla tarla) async {
    final session = ref.read(authProvider).value;
    if (session == null) return;

    if (session.cloudEnabled && session.familyId != null && session.familyId!.isNotEmpty) {
      await CloudSyncService.instance.tarlaEkle(session.familyId!, tarla);
    } else {
      await DatabaseHelper.instance.tarlaEkle(tarla);
    }
    await refreshFields();
  }

  Future<void> updateField(Tarla tarla) async {
    final session = ref.read(authProvider).value;
    if (session == null) return;

    if (session.cloudEnabled && session.familyId != null && session.familyId!.isNotEmpty) {
      await CloudSyncService.instance.tarlaGuncelle(session.familyId!, tarla);
    } else {
      await DatabaseHelper.instance.tarlaGuncelle(tarla);
    }
    await refreshFields();
  }

  Future<void> deleteField(Tarla tarla) async {
    final session = ref.read(authProvider).value;
    if (session == null) return;

    if (session.cloudEnabled && session.familyId != null && session.familyId!.isNotEmpty) {
      await CloudSyncService.instance.tarlaSil(session.familyId!, tarla);
    } else if (tarla.id != null) {
      await DatabaseHelper.instance.tarlaSil(tarla.id!);
    }
    await refreshFields();
    ref.read(deletedFieldsProvider.notifier).refreshFields();
  }

  Future<void> restoreField(Tarla tarla) async {
    final session = ref.read(authProvider).value;
    if (session == null) return;

    if (session.cloudEnabled && session.familyId != null && session.familyId!.isNotEmpty) {
      await CloudSyncService.instance.tarlaGeriYukle(session.familyId!, tarla);
    } else if (tarla.id != null) {
      await DatabaseHelper.instance.tarlaGeriYukle(tarla.id!);
    }
    await refreshFields();
    ref.read(deletedFieldsProvider.notifier).refreshFields();
  }
}

class DeletedFieldsNotifier extends AsyncNotifier<List<Tarla>> {
  @override
  Future<List<Tarla>> build() async {
    return _fetchFields();
  }

  Future<List<Tarla>> _fetchFields() async {
    // Silinen tarlalar her zaman yerel DB'den
    return DatabaseHelper.instance.tumTarlalar(sadeceSilinenler: true);
  }

  Future<void> refreshFields() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchFields());
  }
}
