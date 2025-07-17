import 'package:flutter/material.dart';
import 'bible_reader_screen.dart';
import 'hymns_screen.dart';
import 'download_manager_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeTab(),
    const BibleReaderScreen(),
    const HymnsScreen(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Bible',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Hymns',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gospel Hub'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Gospel Hub',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your spiritual companion for Bible reading and worship',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _ActionCard(
                    icon: Icons.book_outlined,
                    title: 'Read Bible',
                    subtitle: 'KJV in multiple languages',
                    onTap: () {
                      // Navigate to Bible tab
                    },
                  ),
                  _ActionCard(
                    icon: Icons.music_note_outlined,
                    title: 'Browse Hymns',
                    subtitle: '500+ worship songs',
                    onTap: () {
                      // Navigate to Hymns tab
                    },
                  ),
                  _ActionCard(
                    icon: Icons.search,
                    title: 'Search Verses',
                    subtitle: 'Find specific passages',
                    onTap: () {
                      // Open search
                    },
                  ),
                  _ActionCard(
                    icon: Icons.download,
                    title: 'Download Bibles',
                    subtitle: 'Offline reading',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DownloadManagerScreen(),
                        ),
                      );
                    },
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('App Language'),
                  subtitle: const Text('English'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Language selection
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: const Text('Bible Language'),
                  subtitle: const Text('English (KJV)'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Bible language selection
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode),
                  title: const Text('Dark Mode'),
                  trailing: Switch(
                    value: false,
                    onChanged: (value) {
                      // Toggle dark mode
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Manage Downloads'),
                  subtitle: const Text('Bible versions'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Download management
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('Storage'),
                  subtitle: const Text('15.2 MB used'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Storage info
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('About'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // About page
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Help page
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}