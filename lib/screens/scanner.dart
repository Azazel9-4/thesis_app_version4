import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:image/image.dart' as img; // For analyzing brightness & blur
import 'dart:typed_data';

class DocumentScanner extends StatefulWidget {
  const DocumentScanner({super.key});

  @override
  _DocumentScannerState createState() => _DocumentScannerState();
  
}

class _DocumentScannerState extends State<DocumentScanner> {
  int _currentIndex = 0;
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  // 📸 --- IMAGE QUALITY CHECKERS ---

Future<String?> _analyzeImageQuality(File imageFile) async {
  final bytes = await imageFile.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return "Invalid image file.";

  // File size limit check (5MB max)
  final sizeInMB = bytes.lengthInBytes / (1024 * 1024);
  if (sizeInMB > 5) {
    return "File is too large (max 5MB).";
  }

  // Brightness analysis
  double brightness = _calculateBrightness(decoded);
  if (brightness < 40) return "Image is too dark.";
  if (brightness > 280) return "Image is too bright.";

  // Blur detection
  double blur = _estimateBlur(decoded);
  if (blur < 2) return "Image appears blurry.";

  return null; // No issues
}

double _calculateBrightness(img.Image image) {
  double total = 0;
  int count = 0;

  for (int y = 0; y < image.height; y += 10) {
    for (int x = 0; x < image.width; x += 10) {
      final pixel = image.getPixel(x, y); // Pixel object
      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();

      total += (r + g + b) / 3;
      count++;
    }
  }

  return count > 0 ? total / count : 0;
}

double _estimateBlur(img.Image image) {
  double sum = 0;
  int count = 0;

  for (int y = 1; y < image.height - 1; y += 5) {
    for (int x = 1; x < image.width - 1; x += 5) {
      final c = _getLuminance(image.getPixel(x, y));
      final right = _getLuminance(image.getPixel(x + 1, y));
      final down = _getLuminance(image.getPixel(x, y + 1));

      final dx = (c - right).abs();
      final dy = (c - down).abs();
      sum += dx + dy;
      count++;
    }
  }

  return count > 0 ? sum / count : 0;
}

double _getLuminance(img.Pixel pixel) {
  final r = pixel.r.toDouble();
  final g = pixel.g.toDouble();
  final b = pixel.b.toDouble();
  return 0.299 * r + 0.587 * g + 0.114 * b;
}



void _showWarning(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.orangeAccent),
  );
}


  // pick one image from camera
// pick one image from camera
  Future<void> _pickSingleImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final warning = await _analyzeImageQuality(file);
      if (warning != null) {
        _showWarning(warning);
      }

      // ✅ Append instead of replace
      setState(() {
        _images.add(file);
      });
    } else {
      _showWarning("No image captured.");
    }
  }

  Future<void> _pickMultipleImages() async {
    final pickedFiles = await _picker.pickMultiImage();

    // pickMultiImage never returns null in newer versions
    if (pickedFiles.isNotEmpty) {
      List<File> newImages = [];

      for (var e in pickedFiles) {
        final file = File(e.path);

        // Analyze quality (brightness, blur, file size)
      for (int i = 0; i < pickedFiles.length; i++) {
        final file = File(pickedFiles[i].path);
        final warning = await _analyzeImageQuality(file);
        if (warning != null) {
          _showWarning("Image ${i + 1}: $warning"); // <-- updated here
        }
      }
        newImages.add(file);
      }
      setState(() {
        _images.addAll(newImages);
      });
    } else {
      _showWarning("No images selected from gallery.");
    }
  }

 Future<void> _editImage(int index) async {
    if (index < 0 || index >= _images.length) return;
    File file = _images[index];

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.file(
          file,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List bytes) async {
              final tempDir = await getTemporaryDirectory();
              final editedFile = File(
                '${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg',
              );

              await editedFile.writeAsBytes(bytes);

              setState(() {
                _images[index] = editedFile;
              });
              Navigator.pop(context); 
            },
          ),
          configs: ProImageEditorConfigs(
            designMode: ImageEditorDesignMode.material,
          ),
        ),
      ),
    );
  }

Future<void> _scanText() async {
  if (_images.isEmpty) return;

  String formattedText = "";
  bool foundText = false;
  bool animationComplete = false; 

  // 1. Show the Loading/Scanning Dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      double displayProgress = 0;
      bool animateUp = true; 

      return StatefulBuilder(
        builder: (context, setDialogState) {
          // Progress Bar Animation Loop
          Future.delayed(const Duration(milliseconds: 30), () {
            if (context.mounted && displayProgress < 1.0) {
              setDialogState(() {
                displayProgress += 0.05; // Faster increment for better feel
                if (displayProgress >= 1.0) {
                  animationComplete = true; 
                }
              });
            }
          });

          return AlertDialog(
            backgroundColor: const Color(0xFF0D1128),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.document_scanner, size: 50, color: Colors.white24),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: animateUp ? -25.0 : 25.0, end: animateUp ? 25.0 : -25.0),
                      duration: const Duration(seconds: 1),
                      onEnd: () => setDialogState(() => animateUp = !animateUp),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, value),
                          child: Container(
                            width: 60, height: 2,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const Text("Processing Scans...", style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 15),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: displayProgress.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.white10,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 10),
                Text("${(displayProgress.clamp(0.0, 1.0) * 100).toInt()}%", 
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      );
    },
  );

  // 2. Run the actual OCR
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    for (int i = 0; i < _images.length; i++) {
      final inputImage = InputImage.fromFile(_images[i]);
      final recognizedText = await textRecognizer.processImage(inputImage);

      if (recognizedText.blocks.isEmpty) continue;
      foundText = true;

      for (final block in recognizedText.blocks) {
        // Safe check for lines to avoid division by zero
        if (block.lines.isEmpty) continue;
        
        double avgX = block.lines.map((l) => l.boundingBox.left).reduce((a, b) => a + b) / block.lines.length;
        String align = avgX < 50 ? 'left' : avgX > 150 ? 'right' : 'center';
        formattedText += "\n<p style='text-align:$align;'>";
        for (final line in block.lines) {
          String text = line.text.trim();
          bool isBold = text == text.toUpperCase() && text.length > 2;
          formattedText += "<span style='${isBold ? "font-weight:bold;" : ""}'>$text</span><br>";
        }
        formattedText += "</p>\n";
      }
      if (i < _images.length - 1) formattedText += "<hr>";
    }
  } catch (e) {
    debugPrint("OCR Error: $e");
  } finally {
    await textRecognizer.close();

    while (!animationComplete) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Force pop the Dialog
    }
  }

  // 3. Transition to Editor
  if (!foundText) {
    _showWarning("No text detected in any image.");
  } else {
    // Small delay ensures the dialog is fully gone before the next transition
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TextEditorScreen(
            initialText: formattedText,
            fileName: 'Scanned_${DateTime.now().millisecondsSinceEpoch}',
          ),
        ),
        ).then((_) {
  setState(() {
    _images.clear();
  });
});
      
    }
  }
}


Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          // This creates the sliding "pill" background effect
          color: isSelected ? Colors.blue.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.white60,
              size: isSelected ? 28 : 24, // Subtle scale animation
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isSelected ? 1 : 0,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


// --- THE IMAGE CARD DESIGN ---
  Widget _buildSlidableImageCard(int i) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        clipBehavior: Clip.none, // Allows badges to slightly "pop" out
        children: [
          // The Image itself
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _images[i], 
              height: 160, 
              width: 100, 
              fit: BoxFit.cover
            ),
          ),
          
          // Delete badge (Top Left)
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () => setState(() => _images.removeAt(i)),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent, 
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
          
          // Edit badge (Bottom Right)
          Positioned(
            bottom: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _editImage(i),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.blueAccent, 
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- THE "ADD MORE" BOX DESIGN ---
  Widget _buildAddMoreBox() {
    return GestureDetector(
      onTap: _pickMultipleImages,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.blueAccent.withOpacity(0.05),
          border: Border.all(
            color: Colors.blueAccent.withOpacity(0.3), 
            width: 1.5,
            style: BorderStyle.solid, // Use solid since 'dashed' is not standard
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: Colors.blueAccent, size: 28),
            SizedBox(height: 6),
            Text(
              "Add More", 
              style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      ),
    );
  }
  // -------------------
  // Pages / UI
  // -------------------
Widget _homePage() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        // 1. YOUR ORIGINAL WELCOME CARD
        Card(
          color: const Color(0xFF0D1128),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  "Welcome!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text("What would you like to do today?", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _pickSingleImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text("Start Capturing", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 2. YOUR ORIGINAL QUICK ACTIONS
        const Text("Quick Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Card(
                color: const Color(0xFF0D1128),
                child: InkWell(
                  onTap: _pickMultipleImages,
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.photo_library, size: 30, color: Colors.white),
                        SizedBox(height: 8),
                        Text("Import Images", style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 3. HORIZONTAL SLIDER WITH WRAPPING CONTAINER
        if (_images.isNotEmpty) ...[
          Center(
            child: Text(
              "${_images.length} image(s) selected",
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          
          // --- THIS IS THE ADDED CONTAINER WRAPPER ---
          Container(
            height: 184, // Slightly taller to account for padding
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05), // Subtle "shelf" color
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10), // Thin border to define the area
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              physics: const BouncingScrollPhysics(),
              itemCount: _images.length + 1,
              itemBuilder: (context, i) {
                if (i == _images.length) {
                  return _buildAddMoreBox();
                }
                return _buildSlidableImageCard(i);
              },
            ),
          ),
          // -------------------------------------------

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _scanText,
                icon: const Icon(Icons.document_scanner),
                label: const Text("Scan"),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => setState(() => _images = []),
                icon: const Icon(Icons.delete_forever),
                label: const Text("Clear"),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
Future<List<FileSystemEntity>> _loadFiles(Directory dir) async {
  if (!await dir.exists()) return [];

  final entities = await dir.list(recursive: true).toList();

  return entities
      .whereType<File>()
      .where((f) {
        final path = f.path.toLowerCase();
        return path.endsWith(".pdf") ||
            path.endsWith(".docx") ||
            path.endsWith(".txt");
      })
      .toList()
      .reversed
      .toList();
}

Widget _buildSelectionHeader(
  List<FileSystemEntity> files,
  void Function(void Function()) setStateSB,
) {
  bool allSelected = _selectedFiles.length == files.length;

  return Container(
    color: const Color(0xFF061F33),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: () {
            setStateSB(() {
              if (allSelected) {
                _selectedFiles.clear();
              } else {
                _selectedFiles =
                    files.map((f) => f.path).toSet();
              }
            });
          },
          icon: const Icon(Icons.select_all, color: Colors.white),
          label: Text(
            allSelected ? "Unselect All" : "Select All",
            style: const TextStyle(color: Colors.white),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Delete Documents?"),
                content: Text(
                    "Delete ${_selectedFiles.length} item(s)?"),
                actions: [
                  TextButton(
                      onPressed: () =>
                          Navigator.pop(context, false),
                      child: const Text("Cancel")),
                  TextButton(
                      onPressed: () =>
                          Navigator.pop(context, true),
                      child: const Text("Delete")),
                ],
              ),
            );

            if (confirm == true) {
              for (var path in _selectedFiles) {
                final file = File(path);
                if (await file.exists()) {
                  await file.delete();
                }
              }

              setStateSB(() => _selectedFiles.clear());
              setState(() {}); // refresh UI
            }
          },
        ),
      ],
    ),
  );
}
Widget _documentsPage() {
  return FutureBuilder<Directory>(
    future: getApplicationDocumentsDirectory(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final dir = snapshot.data!;
      final docEaseDir =
          Directory('${dir.path}${Platform.pathSeparator}DocEase');

      return FutureBuilder<List<FileSystemEntity>>(
        future: _loadFiles(docEaseDir),
        builder: (context, fileSnapshot) {
          if (!fileSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final files = fileSnapshot.data!;

          if (files.isEmpty) {
            return const Center(
              child: Text(
                "No documents yet",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return StatefulBuilder(
            builder: (context, setStateSB) {
              bool isSelectionMode = _selectedFiles.isNotEmpty;

              return Column(
                children: [
                  if (isSelectionMode)
                    _buildSelectionHeader(files, setStateSB),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index] as File;
                        final name =
                            file.path.split(Platform.pathSeparator).last;
                        final lowerName = name.toLowerCase();
                        final isSelected =
                            _selectedFiles.contains(file.path);
                        final isDraft = lowerName.endsWith(".txt");

                        return GestureDetector(
                          onLongPress: () {
                            setStateSB(() =>
                                _selectedFiles.add(file.path));
                          },
                          onTap: () async {
                            if (isSelectionMode) {
                              setStateSB(() {
                                isSelected
                                    ? _selectedFiles.remove(file.path)
                                    : _selectedFiles.add(file.path);
                              });
                            } else if (isDraft) {
                              final content =
                                  await file.readAsString();

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TextEditorScreen(
                                    initialText: content,
                                    fileName:
                                        name.replaceAll(".txt", ""),
                                  ),
                                ),
                              );
                            } else {
                              OpenFile.open(file.path);
                            }
                          },
                          child: Card(
                            color: isSelected
                                ? Colors.blue.withOpacity(0.3)
                                : const Color(0xFF0D1128),
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.transparent,
                              ),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: Icon(
                                isDraft
                                    ? Icons.edit_note
                                    : lowerName.endsWith(".pdf")
                                        ? Icons.picture_as_pdf
                                        : Icons.description,
                                color: isDraft
                                    ? Colors.amber
                                    : Colors.white,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                    color: Colors.white),
                              ),
                              subtitle: isDraft
                                  ? const Text(
                                      "Draft - Tap to edit",
                                      style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 11),
                                    )
                                  : null,
                              trailing: isSelectionMode
                                  ? Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons
                                              .radio_button_unchecked,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

// Make sure this variable is defined at the top of your State class
Set<String> _selectedFiles = {};
  Widget _settingsPage() {
    return const Center(
      child: Text(
        "Settings will be available soon.",
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? "DocEase"
              : _currentIndex == 1
                  ? "All Documents"
                  : "Settings",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30),
        ),
        backgroundColor: const Color(0xFF061F33),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _homePage(),
          _documentsPage(),
          _settingsPage(),
        ],
      ),
     bottomNavigationBar: Container(
        height: 70,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20), // Floating look
        decoration: BoxDecoration(
          color: const Color(0xFF0D1128),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_filled, "Home"),
            _buildNavItem(1, Icons.folder_rounded, "Docs"),
            _buildNavItem(2, Icons.settings_rounded, "Settings"),
          ],
        ),
      ),
    );
  }
}
