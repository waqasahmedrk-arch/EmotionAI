// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'diagnostic_screen.dart';
import 'predict_screen.dart';
import 'chatbot_screen.dart';
import 'visualization_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? userName;
  bool isGuest = false;
  bool _showWelcomeMessage = true;

  finaFl List<Widget> _tabs = [
    const PredictPage(),
    const DiagnosticPage(),
    const VisualizationScreen(),
    const ChatBotScreen(),
  ];

  final List<String> _tabTitles = [
    'Emotion Prediction',
    'Diagnostics',
    'Analyst',
    'AI Assistant',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void _loadUserInfo() {
    // Get user info from AuthService first
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if we have guest data from navigation arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        setState(() {
          userName = args['userName'] as String?;
          isGuest = args['isGuest'] ?? false;
          _showWelcomeMessage = true;
        });

        // If it's a guest login, update the AuthService
        if (isGuest) {
          authService.setGuestUser(userName ?? 'Guest User');
        }

        // Hide welcome message after 4 seconds
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showWelcomeMessage = false;
            });
          }
        });
      } else {
        // Fallback to AuthService data
        setState(() {
          userName = authService.currentUser?.name ?? 'User';
          isGuest = authService.isGuest;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check for arguments passed from navigation
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null && args.containsKey('userName')) {
      setState(() {
        userName = args['userName'] as String?;
        isGuest = args['isGuest'] ?? false;
        _showWelcomeMessage = true;
      });

      // If it's a guest login, update the AuthService
      if (isGuest) {
        final authService = Provider.of<AuthService>(context, listen: false);
        authService.setGuestUser(userName ?? 'Guest User');
      }

      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _showWelcomeMessage = false;
          });
        }
      });
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _buildLogoutConfirmationDialog();
      },
    );
  }

  Widget _buildLogoutConfirmationDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10.0,
              offset: const Offset(0.0, 10.0),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout,
                    color: Colors.red.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Confirm Logout',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Are you sure you want to logout?',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            if (isGuest)
              Text(
                'You are currently signed in as a guest.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _performLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _performLogout() async {
    Navigator.of(context).pop();

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Call logout from AuthService
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();

    // Close loading dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Navigate to login screen
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
              (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show exit confirmation dialog
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF556B2F),
          automaticallyImplyLeading: false,
          title: Text(
            _tabTitles[_currentIndex],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: IconButton(
                icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                onPressed: _showLogoutConfirmation,
                tooltip: 'Logout',
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _tabs.map((tab) => _ErrorBoundary(child: tab)).toList(),
                  ),
                ),
              ],
            ),
            if (_showWelcomeMessage && userName != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showWelcomeMessage ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF556B2F),
                          Color(0xFF6B8E23),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.waving_hand,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Welcome!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Hello, $userName! 👋',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              if (isGuest)
                                const SizedBox(height: 2),
                              if (isGuest)
                                const Text(
                                  'Guest Mode',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () {
                            setState(() {
                              _showWelcomeMessage = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onTabTapped,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF556B2F),
      unselectedItemColor: Colors.grey[600],
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.psychology_outlined),
          activeIcon: Icon(Icons.psychology),
          label: 'Predict',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Diagnostics',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined),
          activeIcon: Icon(Icons.analytics),
          label: 'Analyst',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_outlined),
          activeIcon: Icon(Icons.chat),
          label: 'AI Assistant',
        ),
      ],
    );
  }
}

class _ErrorBoundary extends StatelessWidget {
  final Widget child;

  const _ErrorBoundary({required this.child});

  @override
  Widget build(BuildContext context) {
    try {
      return child;
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 50),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              e.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Reload the page
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
  }
}