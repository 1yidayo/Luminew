import 'package:flutter/material.dart';
import 'dart:ui';
import '../mock_data.dart';
import '../widgets/luminew_header.dart';

class ClassChatRoom extends StatefulWidget {
  final String chatKey;
  final String userEmail;
  final String title;
  final bool showAppBar;

  final ForumPost? forumPost;

  const ClassChatRoom({
    super.key,
    required this.chatKey,
    required this.userEmail,
    this.title = '公共交流',
    this.showAppBar = false,
    this.forumPost,
  });

  @override
  State<ClassChatRoom> createState() => _ClassChatRoomState();
}

class _ClassChatRoomState extends State<ClassChatRoom> {
  // 保持原本的聊天室邏輯，但隱藏 AppBar
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  void _send() {
    mockService.sendMessage(_ctrl.text, widget.userEmail, widget.chatKey);
    _ctrl.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF0), // 鵝黃背景
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 90), // 留出標頭空間
              Expanded(
                child: StreamBuilder<List<String>>(
                  stream: mockService.getChatStream(widget.chatKey),
                  builder: (ctx, snap) {
                    if (!snap.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final msgs = snap.data!;
                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          msgs.length + (widget.forumPost != null ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (widget.forumPost != null && i == 0) {
                          // 首行顯示：論壇貼文本文
                          return _buildForumPostHeader(widget.forumPost!);
                        }

                        final msgIndex = widget.forumPost != null ? i - 1 : i;
                        final msgFull = msgs[msgIndex];
                        final parts = msgFull.split('：');
                        final sender = parts[0];
                        final content = parts.length > 1
                            ? parts.sublist(1).join('：')
                            : msgFull;
                        final isMe = sender == widget.userEmail.split('@')[0];
                        return _buildChatBubble(sender, content, isMe);
                      },
                    );
                  },
                ),
              ),
              _buildInputArea(),
            ],
          ),
          LuminewHeader(title: widget.title, showBackButton: true),
        ],
      ),
    );
  }

  Widget _buildForumPostHeader(ForumPost post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFAD9DC7).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFAD9DC7).withOpacity(0.1),
                child: Text(
                  post.author[0],
                  style: const TextStyle(
                    color: Color(0xFFAD9DC7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.author,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${post.timestamp.month}/${post.timestamp.day} 發佈',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF675B83),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            post.content,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            '全部評論',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String sender, String content, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) CircleAvatar(radius: 16, child: Text(sender[0])),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFAD9DC7) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                content,
                style: TextStyle(color: isMe ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: '發表評論...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFFAD9DC7)),
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🚀 新增：Discord 論壇風格首頁
// ==========================================
class ClassForumScreen extends StatefulWidget {
  final String userEmail;
  const ClassForumScreen({super.key, required this.userEmail});

  @override
  State<ClassForumScreen> createState() => _ClassForumScreenState();
}

class _ClassForumScreenState extends State<ClassForumScreen> {
  @override
  Widget build(BuildContext context) {
    final posts = mockService.getForumPosts();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF0), // 鵝黃背景
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFFAD9DC7).withOpacity(0.8), // 同步導覽列：80% 通透紫
        child: const Icon(Icons.edit_note, color: Colors.white, size: 30),
      ),
      body: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
            itemCount: posts.length,
            itemBuilder: (ctx, i) => _buildForumCard(posts[i]),
          ),
          const LuminewHeader(title: '互動交流'), // 標題改為互動交流
        ],
      ),
    );
  }

  Widget _buildForumCard(ForumPost post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFAD9DC7).withOpacity(0.15), // 換回淺紫色通透底，不再死白
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFAD9DC7).withOpacity(0.2),
        ), // 紫色細邊框
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassChatRoom(
              chatKey: post.id,
              userEmail: widget.userEmail,
              title: post.title,
              forumPost: post,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 頂部：標題、時間(右上)與收藏
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5A5A5A), // 深灰色標題，取代過硬的黑色
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => mockService.toggleFavorite(post.id)),
                    child: Icon(
                      post.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: post.isFavorite ? Colors.amber : Colors.grey,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 標籤列
              Wrap(
                spacing: 8,
                children: post.tags
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFAD9DC7).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Color(0xFFAD9DC7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),

              Text(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),

              // 底部資訊列 (已移除發布時間)
              Row(
                children: [
                  CircleAvatar(
                    radius: 11, // 稍微調大一點點
                    backgroundColor: const Color(0xFFAD9DC7).withOpacity(0.2),
                    child: Text(
                      post.author[0],
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFAD9DC7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post.author,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('·', style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 6),
                  Text(
                    _getFormattedTime(post.timestamp),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.replyCount}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFormattedTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inHours < 24) return '${diff.inHours}小時前';
    return '${diff.inDays}天前';
  }
}
