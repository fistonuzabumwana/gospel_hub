import 'package:flutter/material.dart';

class HymnsScreen extends StatefulWidget {
  const HymnsScreen({super.key});

  @override
  State<HymnsScreen> createState() => _HymnsScreenState();
}

class _HymnsScreenState extends State<HymnsScreen> {
  String selectedCategory = 'All';
  List<String> categories = ['All', 'Worship', 'Praise', 'Prayer', 'Seasonal'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hymns'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Search hymns
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category selector
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = category == selectedCategory;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        selectedCategory = category;
                      });
                    },
                  ),
                );
              },
            ),
          ),

          // Hymns list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: 20, // Placeholder hymn count
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text('Hymn Title ${index + 1}'),
                    subtitle: Text('Category: ${categories[1]}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite_border),
                      onPressed: () {
                        // Add to favorites
                      },
                    ),
                    onTap: () {
                      _showHymnDetails(index + 1);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showHymnDetails(int hymnNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Hymn header
                  Text(
                    'Hymn $hymnNumber',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Amazing Grace',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // Hymn lyrics
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        '''Amazing grace! How sweet the sound
That saved a wretch like me!
I once was lost, but now am found;
Was blind, but now I see.

'Twas grace that taught my heart to fear,
And grace my fears relieved;
How precious did that grace appear
The hour I first believed.

Through many dangers, toils and snares,
I have already come;
'Tis grace hath brought me safe thus far,
And grace will lead me home.

The Lord has promised good to me,
His Word my hope secures;
He will my Shield and Portion be,
As long as life endures.''',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),

                  // Action buttons
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // Add to favorites
                        },
                        icon: const Icon(Icons.favorite_border),
                        label: const Text('Favorite'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Share hymn
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}