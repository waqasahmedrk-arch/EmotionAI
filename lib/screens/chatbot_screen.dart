import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final List<ChatMessage> _messages = [];
  final List<Map<String, String>> _conversationHistory = []; // 🧠 Memory
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  static const String openAiApiKey = 'AIzaSyDWUi7tmGDb4mt_WiBYhNtoSW21Mbh-E4w';
  static const String openAiModel = 'gpt-3.5-turbo'; // or gpt-4o-mini
   
  // Color Scheme
  final Color _primaryColor = const Color(0xFF556B2F);
  final Color _accentColor = const Color(0xFF6B8E23);
  final Color _lightOlive = const Color(0xFF8FBC8F);
  final Color _backgroundColor = const Color(0xFFF8F9F7);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF2F3E1F);

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    const welcome =
        "Hello! I'm your EEG Analysis Assistant powered by OpenAI.\n\n"
        "I can help you with:\n"
        "• Understanding EEG data formats\n"
        "• Interpreting emotion prediction results\n"
        "• Troubleshooting technical issues\n"
        "• Explaining neural network concepts\n"
        "• Patient report guidance\n\n"
        "How can I assist you today?";

    _messages.add(ChatMessage(text: welcome, isUser: false, timestamp: DateTime.now()));
    _conversationHistory.add({'role': 'assistant', 'content': welcome});
  }

  void _sendMessage() async {
    if (_textController.text.trim().isEmpty) return;

    final userMessage = _textController.text;
    _textController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _conversationHistory.add({'role': 'user', 'content': userMessage});

    await _getAIResponse();

    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  Future<void> _getAIResponse() async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $openAiApiKey',
    };

    final body = jsonEncode({
      'model': openAiModel,
      'messages': [
        {'role': 'system', 'content': '''
You are Mindful Companion, an empathetic AI focused only on emotional well-being and mental health. 
Your purpose is to offer a safe, supportive, and non-judgmental space for users to express feelings and find gentle coping support. 
You are not a therapist or crisis line but a caring listener and guide.

Focus only on: emotions, stress, mindfulness, self-care, coping strategies, reflective listening, and general psychology. 
If asked about news, facts, sports, politics, or unrelated topics, reply: 
"I'm here to focus on your emotional well-being and mental health. Is there something on your mind you'd like to talk about?"

If asked who you are, reply: 
"I'm your Mindful Companion, here to listen and support your emotional wellness."

When users share vague feelings, ask up to 3 empathetic questions (e.g., "Could you tell me more about what's been on your mind?"), then move to supportive reflection. 
Use warm, validating language like: "That sounds really difficult," or "It's understandable to feel that way." 
Never judge or give commands.

If the user mentions self-harm or danger, respond: 
"Your safety is the most important thing. Please contact the 04235765951 Suicide & Crisis Lifeline (PK) or a local crisis service right now."
      '''},
        ..._conversationHistory,
      ],
      'max_tokens': 300,
      'temperature': 0.7,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiText = data['choices'][0]['message']['content'].trim();

        setState(() {
          _messages.add(ChatMessage(
            text: aiText,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });

        _conversationHistory.add({'role': 'assistant', 'content': aiText});
      } else {
        setState(() {
          _messages.add(ChatMessage(
            text: '⚠ Error: ${response.statusCode} - ${response.reasonPhrase}',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: '❌ Failed to connect to OpenAI API.\nError: $e',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _conversationHistory.clear();
      _addWelcomeMessage();
    });
  }

  Widget _buildMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 18),
            ),
          if (!message.isUser) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: message.isUser ? _primaryColor : _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: message.isUser ? null : Border.all(color: _lightOlive.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : _textColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: _textColor.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (message.isUser) const SizedBox(width: 12),
          if (message.isUser)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: _lightOlive.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                  BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.psychology, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EEG Analysis Assistant',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor)),
                      Text('Powered by OpenAI • Memory Enabled',
                          style: TextStyle(fontSize: 12, color: _textColor.withOpacity(0.7))),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.refresh, color: _primaryColor), onPressed: _clearChat),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    return _buildMessage(_messages[index]);
                  } else {
                    return _buildTypingIndicator();
                  }
                },
              ),
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardColor,
              border: Border(top: BorderSide(color: _lightOlive.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _lightOlive.withOpacity(0.5)),
                    ),
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(color: _textColor.withOpacity(0.5), fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: null,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _primaryColor,
                  radius: 20,
                  child: IconButton(
                    icon: _isLoading
                        ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _isLoading ? null : _sendMessage,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration:
            BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.psychology, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _lightOlive.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Thinking...',
                    style: TextStyle(color: _textColor.withOpacity(0.7), fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, required this.timestamp});
}