import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';
import 'chat_detail_screen.dart';

class CategoryModel {
  String name;
  Color color;
  CategoryModel({required this.name, required this.color});
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final List<CategoryModel> _categories = [
    CategoryModel(name: 'All', color: Colors.blue),
    CategoryModel(name: 'Unread', color: Colors.green),
    CategoryModel(name: 'Groups', color: Colors.orange),
    CategoryModel(name: 'Personal', color: Colors.purple),
    CategoryModel(name: 'Work', color: Colors.red),
  ];
  int _selectedCategory = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Chats', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                Row(
                  children: [
                    _iconButton(Icons.camera_alt_outlined, isDark),
                    _iconButton(Icons.more_vert, isDark),
                  ],
                ),
              ],
            ),
          ),

          // Compact Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: TextField(
                      style: TextStyle(fontSize: 14, decoration: TextDecoration.none),
                      decoration: InputDecoration(
                        hintText: 'Search chats...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Categories & Fixed Create Button
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 45,
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      buildDefaultDragHandles: false,
                      itemCount: _categories.length,
                      proxyDecorator: (child, index, animation) => Material(
                        color: Colors.transparent,
                        child: child,
                      ),
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _categories.removeAt(oldIndex);
                          _categories.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == index;
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(cat.name + index.toString()),
                          index: index,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCategory = index),
                            onLongPress: () => _showEditCategoryDialog(context, index),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected 
                                  ? cat.color.withOpacity(isDark ? 0.2 : 0.1) 
                                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? cat.color.withOpacity(0.4) : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  decoration: TextDecoration.none,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? cat.color : (isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildCreateButton(isDesktop, isDark, theme),
              ],
            ),
          ),

          // Chat List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: 15,
              itemBuilder: (context, index) {
                return _buildCompactChatTile(context, index, isDark);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 2,
        onPressed: () {},
        child: const Icon(Icons.chat),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CategoryDialog(
        onSave: (name, color) {
          setState(() {
            _categories.add(CategoryModel(name: name, color: color));
          });
        },
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => _CategoryDialog(
        initialName: _categories[index].name,
        initialColor: _categories[index].color,
        isEditing: true,
        onSave: (name, color) {
          setState(() {
            _categories[index].name = name;
            _categories[index].color = color;
          });
        },
        onDelete: () {
          setState(() {
            _categories.removeAt(index);
            if (_selectedCategory >= _categories.length) _selectedCategory = 0;
          });
        },
      ),
    );
  }

  Widget _buildCreateButton(bool isDesktop, bool isDark, ThemeData theme) {
    return InkWell(
      onTap: () => _showAddCategoryDialog(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
            if (isDesktop) ...[
              const SizedBox(width: 4),
              Text('Create', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Icon(icon, size: 22, color: isDark ? Colors.white70 : Colors.black87),
    );
  }

  Widget _buildCompactChatTile(BuildContext context, int chatIndex, bool isDark) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        ChatDetailScreen.cleanupChat(context, "Tanvir Ahmed"); 
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatDetailScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=compact'),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tanvir Ahmed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: -0.2)),
                      Text('10:45 AM', style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.done_all, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Let us finish the module by tonight.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
                        ),
                      ),
                      if (chatIndex % 3 == 0)
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                          child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                    ],
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

class _CategoryDialog extends StatefulWidget {
  final Function(String, Color) onSave;
  final VoidCallback? onDelete;
  final String? initialName;
  final Color? initialColor;
  final bool isEditing;

  const _CategoryDialog({
    required this.onSave,
    this.onDelete,
    this.initialName,
    this.initialColor,
    this.isEditing = false,
  });

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late TextEditingController _controller;
  late Color _selectedColor;

  final List<Color> _colors = [
    Colors.blue, Colors.green, Colors.orange, Colors.purple, 
    Colors.red, Colors.teal, Colors.pink, Colors.indigo
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _selectedColor = widget.initialColor ?? _colors[0];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isEditing ? 'Edit Category' : 'New Category',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter category name...',
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Pick a Color', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _colors.map((color) {
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == color ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: _selectedColor == color ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.isEditing)
                    TextButton(
                      onPressed: () {
                        widget.onDelete?.call();
                        Navigator.pop(context);
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        widget.onSave(_controller.text, _selectedColor);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(widget.isEditing ? 'Save' : 'Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
