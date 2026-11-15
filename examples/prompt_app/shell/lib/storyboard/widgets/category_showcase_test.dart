import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/models/storyboard_item.dart';
import 'package:skip_shell/storyboard/widgets/category_showcase_viewer.dart';

/// Test page to verify CategoryShowcaseViewer works correctly
/// Run this standalone to test the showcase layout
class CategoryShowcaseTest extends StatelessWidget {
  const CategoryShowcaseTest({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const _TestPage(),
    );
  }
}

class _TestPage extends StatefulWidget {
  const _TestPage();

  @override
  State<_TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<_TestPage> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Showcase Test'),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
        ],
      ),
      body: CategoryShowcaseViewer(
        categoryName: 'Test Components',
        isDarkMode: _isDarkMode,
        itemsBySubcategory: _buildTestItems(),
      ),
    );
  }

  Map<String, List<StoryboardItem>> _buildTestItems() {
    return {
      'Buttons': [
        StoryboardItem(
          name: 'Primary Button (Raw Widget)',
          route: '/test_primary_button',
          icon: Icons.smart_button,
          category: 'Test',
          subcategory: 'Buttons',
          // Raw widget - no Scaffold wrapper
          builder: () => ElevatedButton(
            onPressed: () {},
            child: const Text('Primary Action'),
          ),
        ),
        StoryboardItem(
          name: 'Secondary Button (Raw Widget)',
          route: '/test_secondary_button',
          icon: Icons.smart_button_outlined,
          category: 'Test',
          subcategory: 'Buttons',
          // Raw widget - no Scaffold wrapper
          builder: () => OutlinedButton(
            onPressed: () {},
            child: const Text('Secondary Action'),
          ),
        ),
        StoryboardItem(
          name: 'Button Row (Column of widgets)',
          route: '/test_button_row',
          icon: Icons.view_column,
          category: 'Test',
          subcategory: 'Buttons',
          builder: () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(onPressed: () {}, child: const Text('Button 1')),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: () {}, child: const Text('Button 2')),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: () {}, child: const Text('Button 3')),
            ],
          ),
        ),
      ],
      'Input Fields': [
        StoryboardItem(
          name: 'Text Field (Raw Widget)',
          route: '/test_text_field',
          icon: Icons.text_fields,
          category: 'Test',
          subcategory: 'Input Fields',
          builder: () => const TextField(
            decoration: InputDecoration(
              labelText: 'Enter text',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        StoryboardItem(
          name: 'Search Field (With Container)',
          route: '/test_search_field',
          icon: Icons.search,
          category: 'Test',
          subcategory: 'Input Fields',
          builder: () => Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
      'Cards': [
        StoryboardItem(
          name: 'Info Card (Scaffold-wrapped - legacy)',
          route: '/test_info_card_scaffold',
          icon: Icons.info,
          category: 'Test',
          subcategory: 'Cards',
          // Simulating existing Scaffold-wrapped component
          builder: () => Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info, size: 48, color: Colors.blue),
                        const SizedBox(height: 12),
                        const Text(
                          'Info Card',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This is wrapped in a Scaffold (legacy pattern)',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        StoryboardItem(
          name: 'Success Card (Raw Widget)',
          route: '/test_success_card',
          icon: Icons.check_circle,
          category: 'Test',
          subcategory: 'Cards',
          builder: () => Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Operation completed successfully!'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      'Complex Widgets': [
        StoryboardItem(
          name: 'List Tile Group',
          route: '/test_list_tiles',
          icon: Icons.list,
          category: 'Test',
          subcategory: 'Complex Widgets',
          builder: () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                subtitle: const Text('View your profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                subtitle: const Text('App preferences'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('Help'),
                subtitle: const Text('Get support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
        ),
        StoryboardItem(
          name: 'Chip Group',
          route: '/test_chips',
          icon: Icons.label,
          category: 'Test',
          subcategory: 'Complex Widgets',
          builder: () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: const Text('Flutter')),
              Chip(label: const Text('Dart')),
              Chip(
                avatar: const Icon(Icons.star, size: 18),
                label: const Text('Featured'),
              ),
              ActionChip(label: const Text('Action'), onPressed: () {}),
              FilterChip(
                label: const Text('Filter'),
                selected: true,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ],
    };
  }
}

/// Entry point for testing
void main() {
  runApp(const CategoryShowcaseTest());
}
