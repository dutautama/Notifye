import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../core/router.dart';
import '../auth/auth_controller.dart';
import 'shared_text.dart';

/// Link/teks yang dibagikan ke aplikasi dan menunggu dibuka (mis. saat aplikasi masih terkunci PIN).
class PendingShare extends Notifier<SharedItemDraft?> {
  @override
  SharedItemDraft? build() => null;
  void set(SharedItemDraft d) => state = d;
  void clear() => state = null;
}

final pendingShareProvider = NotifierProvider<PendingShare, SharedItemDraft?>(PendingShare.new);

/// Aktif/tidaknya penerima share. Di test widget di-override false (tidak ada platform channel).
final shareIntentEnabledProvider = Provider<bool>((ref) => true);

/// Menerima share dari aplikasi lain (Android) → buka form "Tambah ke Koleksi"
/// setelah aplikasi tidak terkunci.
class ShareIntentListener extends ConsumerStatefulWidget {
  const ShareIntentListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ShareIntentListener> createState() => _ShareIntentListenerState();
}

class _ShareIntentListenerState extends ConsumerState<ShareIntentListener> {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && ref.read(shareIntentEnabledProvider);

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    final intents = ReceiveSharingIntent.instance;
    intents.getInitialMedia().then(_handle, onError: (_) {});
    _sub = intents.getMediaStream().listen(_handle, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handle(List<SharedMediaFile> files) {
    final text = files
        .where((f) => f.type == SharedMediaType.text || f.type == SharedMediaType.url)
        .map((f) => f.path)
        .join('\n');
    final draft = parseSharedText(text);
    if (draft == null) return;
    ref.read(pendingShareProvider.notifier).set(draft);
    unawaited(ReceiveSharingIntent.instance.reset().then((_) {}, onError: (_) {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryOpen());
  }

  void _tryOpen() {
    if (!mounted) return;
    final draft = ref.read(pendingShareProvider);
    if (draft == null || ref.read(authControllerProvider) != AuthStatus.unlocked) return;
    ref.read(pendingShareProvider.notifier).clear();
    ref.read(routerProvider).push('/koleksi/baru', extra: draft);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      if (next == AuthStatus.unlocked) WidgetsBinding.instance.addPostFrameCallback((_) => _tryOpen());
    });
    return widget.child;
  }
}
