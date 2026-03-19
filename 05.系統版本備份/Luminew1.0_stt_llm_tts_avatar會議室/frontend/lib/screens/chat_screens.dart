import 'package:flutter/material.dart';
import '../mock_data.dart';

class ClassChatRoom extends StatefulWidget {
  final String chatKey;
  final String userEmail;
  final String title;
  final bool showAppBar; // ✅ 控制是否顯示標題

  const ClassChatRoom({
    super.key,
    required this.chatKey,
    required this.userEmail,
    this.title = '聊天室',
    this.showAppBar = true,
  });

  @override
  State<ClassChatRoom> createState() => _ClassChatRoomState();
}

class _ClassChatRoomState extends State<ClassChatRoom> {
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
      backgroundColor: const Color(0xFFF2F4F7), // 仿通訊軟體底色
      appBar: widget.showAppBar ? AppBar(title: Text(widget.title)) : null,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: mockService.getChatStream(widget.chatKey),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data!;
                if (msgs.isEmpty) {
                  return const Center(
                    child: Text("尚無訊息", style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 20,
                  ),
                  itemCount: msgs.length,
                  itemBuilder: (ctx, i) {
                    final msgFull = msgs[i];
                    final parts = msgFull.split('：');
                    final sender = parts[0];
                    final content = parts.length > 1
                        ? parts.sublist(1).join('：')
                        : msgFull;
                    final isMe = sender == widget.userEmail.split('@')[0];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              backgroundColor: Colors.grey[300],
                              radius: 16,
                              child: Text(
                                sender[0],
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFF89D961)
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: isMe
                                      ? const Radius.circular(18)
                                      : const Radius.circular(4),
                                  bottomRight: isMe
                                      ? const Radius.circular(4)
                                      : const Radius.circular(18),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Text(
                                      sender,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  Text(
                                    content,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: '輸入訊息...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
