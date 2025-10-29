import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:image/image.dart' as img; // For analyzing brightness & blur


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



  // 📸 Pick multiple images from gallery
  // 📸 Pick multiple images from gallery
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
      // ✅ Append new gallery images instead of replacing
      setState(() {
        _images.addAll(newImages);
      });
    } else {
      _showWarning("No images selected from gallery.");
    }
  }

  // edit / crop a selected image
  Future<void> _editImage(int index) async {
    if (index < 0 || index >= _images.length) return;
    final file = _images[index];
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop & Rotate',
          toolbarColor: const Color(0xFF100224),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
      ],
    );
    if (croppedFile != null) {
      setState(() => _images[index] = File(croppedFile.path));
    }
  }

// scan all selected images and combine text
Future<void> _scanText() async {
  // --- Stop if no images have been captured or selected ---
  if (_images.isEmpty) return;

  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  String formattedText = "";
  bool foundText = false;

  // --- Loop through each scanned image ---
  for (int i = 0; i < _images.length; i++) {
    final imgFile = _images[i];
    final inputImage = InputImage.fromFile(imgFile);
    final recognizedText = await textRecognizer.processImage(inputImage);

    // Skip if no text found in this image
    if (recognizedText.blocks.isEmpty) continue;
    foundText = true;

    // --- Process text blocks ---
    for (final block in recognizedText.blocks) {
      // Estimate alignment (based on block’s average X position)
      double avgX = block.lines
              .map((l) => l.boundingBox.left)
              .reduce((a, b) => a + b) /
          block.lines.length;

      String align = avgX < 50
          ? 'left'
          : avgX > 150
              ? 'right'
              : 'center';

      formattedText += "\n<p style='text-align:$align;'>";

      // --- Process each line inside the block ---
      for (final line in block.lines) {
        String text = line.text.trim();

        // Simple heuristics to guess bold/italic
        bool isBold = text == text.toUpperCase() && text.length > 2;
        bool isItalic = text.contains(RegExp(r'[\/\\]'));

        formattedText +=
            "<span style='${isBold ? "font-weight:bold;" : ""}${isItalic ? "font-style:italic;" : ""}'>$text</span><br>";
      }

      formattedText += "</p>\n";
    }

    // Add separator between multiple pages/images
    // Only add a page break <hr> if there are multiple scanned images
if (i < _images.length - 1) {
  formattedText += "<hr>";
}

  }

  await textRecognizer.close();

  // --- Handle case where no text is found at all ---
  if (!foundText) {
    _showWarning("No text detected in any image.");
    return;
  }

  // --- Go to text editor and pass formatted HTML text ---
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => TextEditorScreen(
        initialText: formattedText,
        fileName: 'Scanned_${DateTime.now().millisecondsSinceEpoch}', // optional custom name
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
          Card(
            color: const Color(0xFF0D1128),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    "Welcome!",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "What would you like to do today?",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _pickSingleImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, color: Colors.white,),
                    label: const Text(
                      "Start Capturing",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        )),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Quick Actions",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          Text(
                            "Import Images",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // show thumbnails if any
          if (_images.isNotEmpty) ...[
            Center(
              child: Text(
                "${_images.length} image(s) selected",
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                _images.length,
                (i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _images[i],
                        height: 120,
                        width: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _images.removeAt(i);
                          });
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _editImage(i),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
Row(
  mainAxisAlignment: MainAxisAlignment.center, // <-- centers the children
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

 Widget _documentsPage() {
  return FutureBuilder<Directory>(
    future: getApplicationDocumentsDirectory(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final dir = snapshot.data!;
      final files = dir
          .listSync()
          .where((f) => f.path.endsWith(".pdf") || f.path.endsWith(".docx"))
          .toList()
          .reversed
          .toList();

      if (files.isEmpty) {
        return const Center(
          child: Text(
            "No documents yet",
            style: TextStyle(color: Colors.white70),
          ),
        );
      }

      // Track selected files
      Set<String> selectedFiles = {};
      // ignore: unused_local_variable
      bool selectionMode = selectedFiles.isNotEmpty;

      return StatefulBuilder(
        builder: (context, setStateSB) {
          return Column(
            children: [
              if (selectedFiles.isNotEmpty)
                Container(
                  color: const Color(0xFF061F33),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setStateSB(() {
                            if (selectedFiles.length == files.length) {
                              selectedFiles.clear();
                            } else {
                              selectedFiles = files.map((f) => f.path).toSet();
                            }
                          });
                        },
                        icon: const Icon(Icons.select_all, color: Colors.white),
                        label: Text(
                          selectedFiles.length == files.length ? "Unselect All" : "Select All",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Delete Selected Documents?"),
                              content: Text(
                                  "Are you sure you want to delete ${selectedFiles.length} document(s)?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Delete"),
                                ),
                              ],
                            ),
                          );

                          if (confirm ?? false) {
                            for (var path in selectedFiles) {
                              await File(path).delete();
                            }
                            setStateSB(() => selectedFiles.clear());
                            setState(() {}); // refresh parent
                          }
                        },
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final name = file.path.split('/').last;
                    final isSelected = selectedFiles.contains(file.path);

                    return GestureDetector(
                      onLongPress: () {
                        setStateSB(() {
                          selectedFiles.add(file.path);
                        });
                      },
                      onTap: () {
                        if (selectedFiles.isNotEmpty) {
                          setStateSB(() {
                            if (isSelected) {
                              selectedFiles.remove(file.path);
                            } else {
                              selectedFiles.add(file.path);
                            }
                          });
                        } else {
                          OpenFile.open(file.path);
                        }
                      },
                      child: Card(
                        color: isSelected
                            ? Colors.blue.withOpacity(0.5)
                            : const Color(0xFF0D1128),
                        child: ListTile(
                          leading: Icon(
                            file.path.endsWith(".pdf") ? Icons.picture_as_pdf : Icons.description,
                            color: Colors.white,
                          ),
                          title: Text(name, style: const TextStyle(color: Colors.white)),
                          trailing: selectedFiles.isNotEmpty
                              ? Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
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
}


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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.white70,
        backgroundColor: const Color(0xFF0D1128),
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),  
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: "Documents"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}
