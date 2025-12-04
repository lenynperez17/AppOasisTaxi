// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../widgets/animated/modern_animated_widgets.dart';

class CommunicationScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;
  
  CommunicationScreen({super.key, this.tripData});
  
  @override
  _CommunicationScreenState createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends State<CommunicationScreen> 
    with TickerProviderStateMixin {
  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  
  // Communication state
  bool _isTyping = false;
  bool _isCalling = false;
  int _callDuration = 0;
  Timer? _callTimer;
  Timer? _typingTimer;

  // ✅ Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;

  // Messages
  final List<ChatMessage> _messages = [];
  
  // Quick responses
  final List<String> _quickResponses = [
    'Ya llegué, estoy esperando',
    'Voy en camino',
    'Llegaré en 5 minutos',
    'Hay mucho tráfico',
    'No encuentro la dirección',
    '¿Puedes salir?',
    'Estoy en la puerta principal',
    'Necesito cancelar el viaje',
  ];
  
  // Passenger info - Se llenará con datos reales
  final Map<String, dynamic> _passengerInfo = {
    'name': 'Pasajero',
    'photo': '', // Se llenará con datos reales
    'rating': 5.0,
    'trips': 0,
    'phone': '',
    'pickup': '',
    'destination': '',
  };
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _fadeController.forward();
    _initializeChat();
  }
  
  @override
  void dispose() {
    // ✅ Marcar como disposed ANTES de cancelar recursos
    _isDisposed = true;

    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _callTimer?.cancel();
    _callTimer = null;
    _typingTimer?.cancel();
    _typingTimer = null;
    super.dispose();
  }
  
  void _initializeChat() {
    // Add initial automated message
    _messages.add(
      ChatMessage(
        id: '1',
        text: 'Hola, soy tu conductor. Ya estoy en camino a recogerte.',
        isDriver: true,
        timestamp: DateTime.now().subtract(Duration(minutes: 5)),
        status: MessageStatus.read,
      ),
    );
    
    _messages.add(
      ChatMessage(
        id: '2',
        text: 'Perfecto! Estaré esperando en la puerta principal',
        isDriver: false,
        timestamp: DateTime.now().subtract(Duration(minutes: 4)),
        status: MessageStatus.read,
      ),
    );
    
    setState(() {});
  }
  
  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isDriver: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );
    
    setState(() {
      _messages.add(message);
      _messageController.clear();
    });
    
    // Scroll to bottom
    Future.delayed(Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
    
    // Simulate message sent
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        message.status = MessageStatus.sent;
      });
    });
    
    // Simulate message read
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        message.status = MessageStatus.read;
      });
      _simulatePassengerResponse();
    });
  }
  
  void _simulatePassengerResponse() {
    setState(() {
      _isTyping = true;
    });
    
    _typingTimer = Timer(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: _getRandomResponse(),
              isDriver: false,
              timestamp: DateTime.now(),
              status: MessageStatus.read,
            ),
          );
        });
        
        // Scroll to bottom
        Future.delayed(Duration(milliseconds: 100), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }
  
  String _getRandomResponse() {
    final responses = [
      'De acuerdo',
      'Gracias por avisar',
      'Te espero aquí',
      'Ok, entendido',
      'Perfecto',
      'Sin problema',
    ];
    return responses[DateTime.now().millisecond % responses.length];
  }
  
  void _startCall() {
    setState(() {
      _isCalling = true;
      _callDuration = 0;
    });
    
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      // ✅ TRIPLE VERIFICACIÓN para prevenir setState después de dispose
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _callDuration++;
      });
    });
    
    // Show calling dialog
    _showCallDialog();
  }
  
  void _endCall() {
    _callTimer?.cancel();
    setState(() {
      _isCalling = false;
    });
    Navigator.pop(context);
  }
  
  void _showCallDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ModernTheme.oasisBlack,
                ModernTheme.oasisBlack.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Llamando a',
                style: TextStyle(
                  color: context.surfaceColor.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _passengerInfo['name'],
                style: TextStyle(
                  color: context.surfaceColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Text(
                _passengerInfo['phone'],
                style: TextStyle(
                  color: context.surfaceColor.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 24),
              
              // Avatar with pulse animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(_passengerInfo['photo']),
                    ),
                  );
                },
              ),
              SizedBox(height: 24),
              
              // Call duration
              Text(
                _formatCallDuration(_callDuration),
                style: TextStyle(
                  color: context.surfaceColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 32),
              
              // Call actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCallAction(
                    Icons.volume_up,
                    'Altavoz',
                    context.surfaceColor,
                    () {},
                  ),
                  _buildCallAction(
                    Icons.mic_off,
                    'Silenciar',
                    context.surfaceColor,
                    () {},
                  ),
                  _buildCallAction(
                    Icons.dialpad,
                    'Teclado',
                    context.surfaceColor,
                    () {},
                  ),
                ],
              ),
              SizedBox(height: 24),
              
              // End call button
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: ModernTheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.call_end,
                    color: context.surfaceColor,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCallAction(IconData icon, String label, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatCallDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(_passengerInfo['photo']),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _passengerInfo['name'],
                    style: TextStyle(
                      color: context.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: ModernTheme.accentYellow),
                      SizedBox(width: 4),
                      Text(
                        '${_passengerInfo['rating']}',
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${_passengerInfo['trips']} viajes',
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.call, color: ModernTheme.oasisGreen),
            onPressed: _startCall,
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: context.secondaryText),
            onPressed: () => _showOptionsMenu(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Trip info bar
          Container(
            padding: EdgeInsets.all(12),
            color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: ModernTheme.oasisGreen, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recogida: ${_passengerInfo['pickup']}',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Destino: ${_passengerInfo['destination']}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Chat messages
          Expanded(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping && index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessage(_messages[index]);
                    },
                  ),
                );
              },
            ),
          ),
          
          // Quick responses
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickResponses.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(_quickResponses[index]),
                    onPressed: () => _sendMessage(_quickResponses[index]),
                    backgroundColor: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                      color: ModernTheme.oasisGreen,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8),
          
          // Message input
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: context.primaryText.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Attach button
                  IconButton(
                    icon: Icon(Icons.attach_file, color: context.secondaryText),
                    onPressed: () => _showAttachmentOptions(),
                  ),
                  
                  // Text field
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: context.backgroundColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  
                  // Send button
                  Container(
                    decoration: BoxDecoration(
                      color: ModernTheme.oasisGreen,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: context.surfaceColor),
                      onPressed: () => _sendMessage(_messageController.text),
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
  
  Widget _buildMessage(ChatMessage message) {
    final isDriver = message.isDriver;
    
    return Align(
      alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isDriver ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDriver ? ModernTheme.oasisGreen : context.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: isDriver ? Radius.circular(16) : Radius.circular(4),
                  bottomRight: isDriver ? Radius.circular(4) : Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.primaryText.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isDriver ? context.surfaceColor : context.primaryText,
                      fontSize: 14,
                    ),
                  ),
                  if (message.attachment != null)
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.surfaceColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getAttachmentIcon(message.attachment!['type']),
                            color: isDriver ? context.surfaceColor : ModernTheme.oasisGreen,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            message.attachment!['name'],
                            style: TextStyle(
                              color: isDriver ? context.surfaceColor : context.primaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: context.secondaryText,
                    fontSize: 11,
                  ),
                ),
                if (isDriver) ...[
                  SizedBox(width: 4),
                  Icon(
                    message.status == MessageStatus.sending
                        ? Icons.access_time
                        : message.status == MessageStatus.sent
                            ? Icons.done
                            : Icons.done_all,
                    size: 14,
                    color: message.status == MessageStatus.read
                        ? ModernTheme.primaryBlue
                        : context.secondaryText,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.primaryText.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernLoadingIndicator(
              color: ModernTheme.oasisGreen,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Escribiendo...',
              style: TextStyle(
                color: context.secondaryText,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  IconData _getAttachmentIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'location':
        return Icons.location_on;
      case 'audio':
        return Icons.mic;
      default:
        return Icons.attach_file;
    }
  }
  
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enviar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  Icons.image,
                  'Foto',
                  ModernTheme.primaryBlue,
                  () {
                    Navigator.pop(context);
                    _sendAttachment('image', 'Foto.jpg');
                  },
                ),
                _buildAttachmentOption(
                  Icons.location_on,
                  'Ubicación',
                  ModernTheme.oasisGreen,
                  () {
                    Navigator.pop(context);
                    _sendAttachment('location', 'Mi ubicación actual');
                  },
                ),
                _buildAttachmentOption(
                  Icons.mic,
                  'Audio',
                  ModernTheme.accentYellow,
                  () {
                    Navigator.pop(context);
                    _sendAttachment('audio', 'Mensaje de voz');
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAttachmentOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
  
  void _sendAttachment(String type, String name) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: type == 'location' ? 'Compartí mi ubicación' : 'Archivo adjunto',
      isDriver: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      attachment: {
        'type': type,
        'name': name,
      },
    );
    
    setState(() {
      _messages.add(message);
    });
    
    // Simulate sending
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        message.status = MessageStatus.sent;
      });
    });
  }
  
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Ver perfil del pasajero'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.location_on),
              title: Text('Ver ubicación en mapa'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.report),
              title: Text('Reportar problema'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: ModernTheme.error),
              title: Text('Bloquear usuario', 
                style: TextStyle(color: ModernTheme.error)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Chat message model
class ChatMessage {
  final String id;
  final String text;
  final bool isDriver;
  final DateTime timestamp;
  MessageStatus status;
  final Map<String, dynamic>? attachment;
  
  ChatMessage({
    required this.id,
    required this.text,
    required this.isDriver,
    required this.timestamp,
    required this.status,
    this.attachment,
  });
}

enum MessageStatus { sending, sent, read }