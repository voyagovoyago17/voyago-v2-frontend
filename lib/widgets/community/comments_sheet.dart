import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../api/api_exceptions.dart';
import '../../models/community_comment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../theme.dart';
import 'social_actions.dart';

/// Ouvre les commentaires d'un voyage (`trip`) ou d'une publication (`post`).
/// [onCountChanged] reçoit le nouveau nombre de commentaires après un ajout ou une suppression.
Future<void> showCommentsSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  String? title,
  ValueChanged<int>? onCountChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: VoyagoColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CommentsSheet(
      targetType: targetType,
      targetId: targetId,
      title: title,
      onCountChanged: onCountChanged,
    ),
  );
}

/// Demande un motif puis signale le contenu. Renvoie true si le signalement est parti.
Future<bool> reportContent(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
}) async {
  const reasons = ['Contenu inapproprié', 'Harcèlement', 'Spam', 'Fausse information', 'Autre'];
  final reason = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: VoyagoColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Pourquoi signaler ce contenu ?',
              style: TextStyle(color: VoyagoColors.text, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          for (final r in reasons)
            ListTile(
              title: Text(r, style: const TextStyle(color: VoyagoColors.text)),
              onTap: () => Navigator.of(ctx).pop(r),
            ),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(communityApiProvider).report(targetType: targetType, targetId: targetId, reason: reason);
    messenger.showSnackBar(
      const SnackBar(content: Text('Merci, notre équipe va examiner ce signalement.')),
    );
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
    return false;
  }
}

class _CommentsSheet extends ConsumerStatefulWidget {
  final String targetType;
  final String targetId;
  final String? title;
  final ValueChanged<int>? onCountChanged;

  const _CommentsSheet({
    required this.targetType,
    required this.targetId,
    this.title,
    this.onCountChanged,
  });

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  List<CommunityComment> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  CommunityComment? _replyTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final comments = await ref.read(communityApiProvider).getComments(widget.targetType, widget.targetId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
        _error = null;
      });
      widget.onCountChanged?.call(comments.length);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment = await ref.read(communityApiProvider).addComment(
            targetType: widget.targetType,
            targetId: widget.targetId,
            content: text,
            parentId: _replyTo?.id,
          );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, comment];
        _replyTo = null;
        _inputController.clear();
      });
      widget.onCountChanged?.call(_comments.length);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(CommunityComment comment) async {
    try {
      await ref.read(communityApiProvider).deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _comments = _comments.where((c) => c.id != comment.id && c.parentId != comment.id).toList();
        if (_replyTo?.id == comment.id) _replyTo = null;
      });
      widget.onCountChanged?.call(_comments.length);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)),
        );
      }
    }
  }

  void _startReply(CommunityComment comment) {
    // Les réponses se rattachent toujours au commentaire racine
    final root = comment.parentId == null
        ? comment
        : _comments.firstWhere((c) => c.id == comment.parentId, orElse: () => comment);
    setState(() => _replyTo = root);
    _focusNode.requestFocus();
  }

  Future<void> _showActions(CommunityComment comment) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: VoyagoColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: VoyagoColors.text),
              title: const Text('Répondre', style: TextStyle(color: VoyagoColors.text)),
              onTap: () => Navigator.of(ctx).pop('reply'),
            ),
            if (comment.canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: VoyagoColors.coral),
                title: const Text('Supprimer', style: TextStyle(color: VoyagoColors.coral)),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
            if (comment.authorId != ref.read(currentUserProvider)?.userId) ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: VoyagoColors.muted),
                title: const Text('Signaler', style: TextStyle(color: VoyagoColors.text)),
                onTap: () => Navigator.of(ctx).pop('report'),
              ),
              ListTile(
                leading: const Icon(Icons.block, color: VoyagoColors.coral),
                title: Text('Bloquer ${comment.authorDisplayName}', style: const TextStyle(color: VoyagoColors.coral)),
                onTap: () => Navigator.of(ctx).pop('block'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'reply':
        _startReply(comment);
      case 'delete':
        await _delete(comment);
      case 'report':
        await reportContent(context, ref, targetType: 'comment', targetId: comment.id);
      case 'block':
        final blocked = await confirmBlockUser(
          context,
          ref,
          userId: comment.authorId,
          name: comment.authorDisplayName,
        );
        if (blocked && mounted) {
          await _load();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(currentUserProvider) != null;
    final roots = _comments.where((c) => c.parentId == null).toList();
    final repliesByParent = <String, List<CommunityComment>>{};
    for (final c in _comments.where((c) => c.parentId != null)) {
      repliesByParent.putIfAbsent(c.parentId!, () => []).add(c);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VoyagoColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title ?? 'Commentaires',
                      style: const TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!_loading && _error == null)
                    Text('${_comments.length}', style: const TextStyle(color: VoyagoColors.muted)),
                ],
              ),
            ),
            const Divider(height: 1, color: VoyagoColors.cardBorder),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: VoyagoColors.primary))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: VoyagoColors.muted)),
                          ),
                        )
                      : roots.isEmpty
                          ? const Center(
                              child: Text(
                                'Aucun commentaire pour le moment.\nLance la conversation ! 💬',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: VoyagoColors.muted),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              children: [
                                for (final root in roots) ...[
                                  _CommentTile(
                                    comment: root,
                                    onReply: isLoggedIn ? () => _startReply(root) : null,
                                    onLongPress: isLoggedIn ? () => _showActions(root) : null,
                                  ),
                                  for (final reply in repliesByParent[root.id] ?? const <CommunityComment>[])
                                    _CommentTile(
                                      comment: reply,
                                      isReply: true,
                                      onReply: isLoggedIn ? () => _startReply(reply) : null,
                                      onLongPress: isLoggedIn ? () => _showActions(reply) : null,
                                    ),
                                ],
                              ],
                            ),
            ),
            if (_error == null) _buildInput(isLoggedIn),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(bool isLoggedIn) {
    if (!isLoggedIn) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Connecte-toi pour commenter', style: TextStyle(color: VoyagoColors.muted)),
        ),
      );
    }
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: VoyagoColors.cardBorder)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Réponse à ${_replyTo!.authorDisplayName}',
                        style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _replyTo = null),
                      child: const Icon(Icons.close, size: 16, color: VoyagoColors.muted),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _replyTo != null ? 'Écris ta réponse...' : 'Écris un commentaire...',
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: VoyagoColors.primary),
                        )
                      : const Icon(Icons.send_rounded, color: VoyagoColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommunityComment comment;
  final bool isReply;
  final VoidCallback? onReply;
  final VoidCallback? onLongPress;

  const _CommentTile({
    required this.comment,
    this.isReply = false,
    this.onReply,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = isReply ? 28.0 : 34.0;
    return InkWell(
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isReply ? 58 : 16, 6, 16, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthorAvatar(picture: comment.authorPicture, emoji: comment.authorEmoji, size: avatarSize),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: VoyagoColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.authorDisplayName,
                          style: const TextStyle(color: VoyagoColors.text, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(comment.content, style: const TextStyle(color: VoyagoColors.text, fontSize: 14, height: 1.35)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Row(
                      children: [
                        Text(timeAgo(comment.createdAt), style: const TextStyle(color: VoyagoColors.muted, fontSize: 11)),
                        if (onReply != null) ...[
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: onReply,
                            child: const Text(
                              'Répondre',
                              style: TextStyle(color: VoyagoColors.muted, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        if (onLongPress != null) ...[
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: onLongPress,
                            child: const Icon(Icons.more_horiz, size: 16, color: VoyagoColors.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar rond : photo si disponible, sinon l'émoji du voyageur.
class AuthorAvatar extends StatelessWidget {
  final String? picture;
  final String emoji;
  final double size;

  const AuthorAvatar({super.key, this.picture, required this.emoji, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final fallback = Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.5)));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: VoyagoColors.background,
        shape: BoxShape.circle,
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: picture != null && picture!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: picture!,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            )
          : fallback,
    );
  }
}

/// « Il y a 5 min », « Il y a 3h », « Il y a 2j », puis la date.
String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return "À l'instant";
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
  return DateFormat('d MMM yyyy', 'fr').format(date);
}
