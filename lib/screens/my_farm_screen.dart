import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Simple data model representing a crop plot (serializable).
class CropPlot {
  String name;
  String cropType;
  double areaInAcres;

  CropPlot({
    required this.name,
    required this.cropType,
    required this.areaInAcres,
  });

  /// Convert to JSON for Hive storage.
  Map<String, dynamic> toJson() => {
    'name': name,
    'cropType': cropType,
    'areaInAcres': areaInAcres,
  };

  /// Create from JSON (from Hive storage).
  factory CropPlot.fromJson(Map<dynamic, dynamic> json) => CropPlot(
    name: json['name'] as String,
    cropType: json['cropType'] as String,
    areaInAcres: (json['areaInAcres'] as num).toDouble(),
  );
}

/// Screen where users can Add / Edit / Delete their crop plots.
/// Uses Hive for persistent storage across app sessions.
class MyFarmScreen extends StatefulWidget {
  const MyFarmScreen({super.key});

  @override
  State<MyFarmScreen> createState() => _MyFarmScreenState();
}

class _MyFarmScreenState extends State<MyFarmScreen> {
  late Box<dynamic> _plotsBox;
  List<CropPlot> _plots = [];

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  /// Initialize Hive box and load plots.
  Future<void> _initializeHive() async {
    _plotsBox = await Hive.openBox('crop_plots');
    _loadPlots();
  }

  /// Load plots from Hive storage.
  void _loadPlots() {
    if (!mounted) return;
    setState(() {
      _plots = [];
      for (var i = 0; i < _plotsBox.length; i++) {
        final data = _plotsBox.getAt(i);
        if (data != null) {
          _plots.add(CropPlot.fromJson(data));
        }
      }
    });
  }

  /// Save a single plot to Hive.
  Future<void> _savePlot(int index, CropPlot plot) async {
    await _plotsBox.putAt(index, plot.toJson());
  }

  /// Add a new plot to Hive.
  Future<void> _addPlot(CropPlot plot) async {
    await _plotsBox.add(plot.toJson());
    _loadPlots();
  }

  /// Delete a plot from Hive.
  Future<void> _deletePlot(int index) async {
    await _plotsBox.deleteAt(index);
    _loadPlots();
  }

  void _showPlotDialog({CropPlot? existingPlot, int? index}) {
    final nameController = TextEditingController(text: existingPlot?.name ?? '');
    final cropController = TextEditingController(text: existingPlot?.cropType ?? '');
    final areaController = TextEditingController(
      text: existingPlot != null ? existingPlot.areaInAcres.toString() : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existingPlot == null ? 'Add Crop Plot' : 'Edit Crop Plot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Plot Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cropController,
                decoration: const InputDecoration(labelText: 'Crop Type'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: areaController,
                decoration: const InputDecoration(labelText: 'Area (acres)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final crop = cropController.text.trim();
                final area = double.tryParse(areaController.text.trim()) ?? 0.0;

                if (name.isEmpty || crop.isEmpty || area <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields correctly')),
                  );
                  return;
                }

                final newPlot = CropPlot(name: name, cropType: crop, areaInAcres: area);

                if (existingPlot == null) {
                  // Adding new plot
                  await _addPlot(newPlot);
                } else if (index != null) {
                  // Updating existing plot
                  await _savePlot(index, newPlot);
                  _loadPlots();
                }

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plot'),
        content: Text('Remove "${_plots[index].name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _deletePlot(index);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _plots.isEmpty
          ? const Center(child: Text('No crop plots yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _plots.length,
              itemBuilder: (context, index) {
                final plot = _plots[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: ListTile(
                    leading: const Icon(Icons.grass, color: Colors.green),
                    title: Text(plot.name),
                    subtitle: Text('${plot.cropType} • ${plot.areaInAcres} acres'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showPlotDialog(existingPlot: plot, index: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPlotDialog(),
        tooltip: 'Add Crop Plot',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    // Optional: Close box when screen is disposed
    // Hive manages this automatically, but you can be explicit
    super.dispose();
  }
}