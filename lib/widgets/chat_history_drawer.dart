import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/chat_session.dart';
import '../providers/ask_library_chat_provider.dart';
import '../providers/ask_library_chat_history_provider.dart';
import '../providers/ask_library_session_provider.dart';

class ChatHistoryDrawer extends ConsumerWidget {
  const ChatHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(askLibraryChatHistoryProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref),
            const Divider(),
            Expanded(
              child: sessions.isEmpty
                  ? const Center(child: Text('No saved chats'))
                  : ListView.builder(
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        return _ChatListItem(session: sessions[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Chat History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              ref.read(askLibraryChatProvider.notifier).newChat();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add),
            label: const Text('New Chat'),
          ),
        ],
      ),
    );
  }
}

class _ChatListItem extends ConsumerWidget {
  final ChatSession session;

  const _ChatListItem({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Slidable(
      key: ValueKey(session.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => _showRenameDialog(context, ref),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
            icon: Icons.edit,
            label: 'Rename',
          ),
          SlidableAction(
            onPressed: (_) => _confirmDelete(context, ref),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: ListTile(
        title: Text(session.title),
        onTap: () {
          ref.read(askLibrarySessionProvider.notifier).loadSession(session);
          Navigator.pop(context);
        },
        onLongPress: () => _showActionsBottomSheet(context, ref),
      ),
    );
  }

  void _showActionsBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, ref);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => _RenameDialog(
        initialTitle: session.title,
        onSave: (newTitle) {
          ref
              .read(askLibraryChatHistoryProvider.notifier)
              .renameSession(session.id, newTitle);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(askLibraryChatHistoryProvider.notifier)
                  .deleteSession(session.id);
              Navigator.pop(context);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final String initialTitle;
  final ValueChanged<String> onSave;

  const _RenameDialog({required this.initialTitle, required this.onSave});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Chat'),
      content: TextField(controller: _controller),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            widget.onSave(_controller.text);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
