import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/home_screen.dart';
import 'screens/my_farm_screen.dart';
import 'screens/ai_advisor_screen.dart';

void main() async {
  // Initialize flutter_dotenv to load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // .env file may not exist on some builds - this is ok
    // Groq API will simply be unavailable
  }
  
  // Initialize Hive for data persistence
  await Hive.initFlutter();
  
  runApp(const IrrigationCultivatorApp());
}

class IrrigationCultivatorApp extends StatelessWidget {
  const IrrigationCultivatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Irrigation Cultivator Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const List<String> _titles = ['Home Dashboard', 'My Farm', 'AI Advisor'];

  static const List<Widget> _screens = [
    HomeScreen(),
    MyFarmScreen(),
    AIAdvisorScreen(),
  ];

  void _onDrawerItemTapped(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      drawer: _buildDrawer(context),
      body: _screens[_selectedIndex],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.eco, color: Colors.white, size: 40),
                SizedBox(height: 8),
                Text('Irrigation Cultivator',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Assistant', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            selected: _selectedIndex == 0,
            onTap: () => _onDrawerItemTapped(0),
          ),
          ListTile(
            leading: const Icon(Icons.agriculture),
            title: const Text('My Farm'),
            selected: _selectedIndex == 1,
            onTap: () => _onDrawerItemTapped(1),
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('AI Advisor'),
            selected: _selectedIndex == 2,
            onTap: () => _onDrawerItemTapped(2),
          ),
        ],
      ),
    );
  }
}