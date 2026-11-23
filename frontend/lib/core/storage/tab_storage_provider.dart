import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'tab_storage.dart';

part 'tab_storage_provider.g.dart';

/// This tab's own storage (`TabStorage`); a test overrides it with memory.
@Riverpod(keepAlive: true)
TabStorage tabStorage(Ref ref) => openTabStorage();
