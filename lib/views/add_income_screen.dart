import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// ignore_for_file: prefer_final_fields, prefer_const_constructors, unused_field, unused_element

class AddIncomeScreen extends StatefulWidget {
  final double? preFilledAmount;
  
  const AddIncomeScreen({super.key, this.preFilledAmount});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  late final TextEditingController _amountController;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _paymentSearchController = TextEditingController();
  
  String _selectedCategory = 'Allowance';
  IconData _selectedCategoryIcon = Icons.account_balance_wallet_outlined;
  String _selectedPaymentMethod = 'Bank';
  String _selectedTimeOfDay = DateFormat('hh:mm a').format(DateTime.now());
  String _searchQuery = '';
  String _searchPaymentQuery = '';
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  bool _isRecurring = false;
  bool _isLoading = false;
  
  // Bills images list
  List<File> _billImages = [];
  
  // Payment methods list (mutable for adding new)
  List<String> _paymentMethodsList = [
    'Bank', 'Cash', 'Credit Card', 'Debit Card', 'Mobile Wallet', 'Other'
  ];
 
  List<Map<String, dynamic>> _categories = [
    {'name': 'Allowance', 'icon': Icons.account_balance_wallet_outlined, 'color': Color(0xFFFBBF24)}, 
    {'name': 'Bonus', 'icon': Icons.card_giftcard, 'color': Color(0xFF34D399)},
    {'name': 'Business', 'icon': Icons.business_center, 'color': Color(0xFF60A5FA)},
    {'name': 'Investment Income', 'icon': Icons.trending_up, 'color': Color(0xFFF472B6)},
    {'name': 'Other Income', 'icon': Icons.info_outline, 'color': Color(0xFF9CA3AF)},
    {'name': 'Pension', 'icon': Icons.assignment_ind_outlined, 'color': Color(0xFFFB7185)},
    {'name': 'Salary', 'icon': Icons.payments_outlined, 'color': Color(0xFF34D399)},
    {'name': 'Shopping', 'icon': Icons.shopping_bag_outlined, 'color': Color(0xFFF87171)},
  ];
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();
  
  String? get _currentUserId => _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    if (widget.preFilledAmount != null) {
      _amountController.text = widget.preFilledAmount!.toString();
    }
    _loadCategoriesFromFirestore();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    _paymentSearchController.dispose();
    super.dispose();
  }

  // Save categories to Firestore
  Future<void> _saveCategoriesToFirestore() async {
    if (_currentUserId == null) return;
    
    try {
      final List<Map<String, dynamic>> categoriesToSave = _categories.map((cat) {
        return {
          'name': cat['name'],
          'icon': _getIconString(cat['icon']),
          'color': (cat['color'] as Color).toARGB32(),
        };
      }).toList();
      
      await _firestore.collection('user_categories').doc(_currentUserId).set({
        'categories': categoriesToSave,
      });
    } catch (e) {
      // print('Error saving categories: $e');
    }
  }

  // Load categories from Firestore
  Future<void> _loadCategoriesFromFirestore() async {
    if (_currentUserId == null) return;
    
    try {
      final doc = await _firestore.collection('user_categories').doc(_currentUserId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> savedCategories = data['categories'] ?? [];
        
        if (savedCategories.isNotEmpty) {
          final List<Map<String, dynamic>> loadedCategories = [];
          for (var cat in savedCategories) {
            loadedCategories.add({
              'name': cat['name'],
              'icon': _getIconFromString(cat['icon']),
              'color': Color(cat['color']),
            });
          }
          setState(() {
            _categories = loadedCategories;
          });
        }
      }
    } catch (e) {
      // print('Error loading categories: $e');
    }
  }

  // Convert IconData to String for storage
  String _getIconString(IconData icon) {
    if (icon == Icons.account_balance_wallet_outlined) return 'account_balance_wallet_outlined';
    if (icon == Icons.card_giftcard) return 'card_giftcard';
    if (icon == Icons.business_center) return 'business_center';
    if (icon == Icons.trending_up) return 'trending_up';
    if (icon == Icons.info_outline) return 'info_outline';
    if (icon == Icons.assignment_ind_outlined) return 'assignment_ind_outlined';
    if (icon == Icons.payments_outlined) return 'payments_outlined';
    if (icon == Icons.shopping_bag_outlined) return 'shopping_bag_outlined';
    if (icon == Icons.star_outline) return 'star_outline';
    return 'star_outline';
  }

  // Convert String to IconData
  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'account_balance_wallet_outlined':
        return Icons.account_balance_wallet_outlined;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'business_center':
        return Icons.business_center;
      case 'trending_up':
        return Icons.trending_up;
      case 'info_outline':
        return Icons.info_outline;
      case 'assignment_ind_outlined':
        return Icons.assignment_ind_outlined;
      case 'payments_outlined':
        return Icons.payments_outlined;
      case 'shopping_bag_outlined':
        return Icons.shopping_bag_outlined;
      case 'star_outline':
        return Icons.star_outline;
      default:
        return Icons.star_outline;
    }
  }

  // ==================== PAYMENT METHOD MODAL ====================
  
void _showPaymentMethodSelection() {
  _searchPaymentQuery = '';
  _paymentSearchController.clear();

  showModalBottomSheet(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final filteredMethods = _paymentMethodsList.where((method) {
            return method.toLowerCase().contains(_searchPaymentQuery.toLowerCase());
          }).toList();

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Wallet Icon, Title and Add New Button
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFEC407A), size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddNewPaymentMethodDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFEC407A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Add New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Search Bar
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: TextField(
                    controller: _paymentSearchController,
                    onChanged: (value) {
                      setSheetState(() {
                        _searchPaymentQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Color(0xFFEC407A), size: 22),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Payment Methods List
                SizedBox(
                  height: 250,
                  child: filteredMethods.isEmpty
                      ? const Center(child: Text('No payment methods found', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: filteredMethods.length,
                          itemBuilder: (context, index) {
                            final method = filteredMethods[index];
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    method,
                                    style: const TextStyle(fontSize: 16, color: Colors.black),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedPaymentMethod = method;
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                                Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

void _showAddNewPaymentMethodDialog() {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();
  bool isPositive = true;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            // Thoda boxy look jesa image ma hai (BorderRadius kam kiya hai)
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            title: const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.bold, 
                color: Color(0xFF141E27), // Charcoal Color
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  // Name Input Field
                  TextField(
                    controller: nameController,
                    cursorColor: const Color(0xFFEC407A), // Pink Color
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                      floatingLabelStyle: const TextStyle(color: Color(0xFFEC407A)), // Pink on Focus
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF213140), width: 1.5), // Midnight Blue on Focus
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Opening Balance Input Field
                  TextField(
                    controller: balanceController,
                    keyboardType: TextInputType.number,
                    cursorColor: const Color(0xFFEC407A), // Pink Color
                    decoration: InputDecoration(
                      labelText: 'Opening Balance [Optional]',
                      labelStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                      floatingLabelStyle: const TextStyle(color: Color(0xFFEC407A)), // Pink on Focus
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF213140), width: 1.5), // Midnight Blue on Focus
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Plus / Minus Selection Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => setDialogState(() => isPositive = true),
                        child: Row(
                          children: [
                            Icon(
                              isPositive ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: Colors.teal,
                              size: 26,
                            ),
                            const SizedBox(width: 6),
                            const Text('+', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.teal)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 45),
                      GestureDetector(
                        onTap: () => setDialogState(() => isPositive = false),
                        child: Row(
                          children: [
                            Icon(
                              !isPositive ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: Colors.red,
                              size: 26,
                            ),
                            const SizedBox(width: 6),
                            const Text('-', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Date Picker Display Field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('dd-MMM-yyyy').format(DateTime.now()), 
                          style: const TextStyle(fontSize: 16, color: Colors.black)
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.calendar_month, color: Color(0xFFEC407A)), // Muted Pink Icon
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'CANCEL', 
                  style: TextStyle(
                    color: Color(0xFF213140), // Midnight Blue
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  final newName = nameController.text.trim();
                  if (newName.isNotEmpty) {
                    setState(() {
                      _paymentMethodsList.add(newName);
                      _selectedPaymentMethod = newName;
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'SAVE', 
                  style: TextStyle(
                    color: Color(0xFFEC407A), // Pink Color
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
  // ==================== ADD BILLS FUNCTIONS ====================
  
  void _showAddBillsDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              
              const Text(
                'Add Bills',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 20),
              
              _buildOptionButton(
                icon: Icons.camera_alt,
                label: 'Camera',
                color: const Color(0xFFEC407A),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageFromCamera();
                },
              ),
              const SizedBox(height: 16),
              
              _buildOptionButton(
                icon: Icons.photo_library,
                label: 'Gallery',
                color: const Color(0xFFEC407A),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageFromGallery();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _billImages.add(File(image.path));
        });
        _showBillImagesPreview();
      }
    } catch (e) {
      _showSnackBar('Error accessing camera: $e');
    }
  }
  
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _billImages.add(File(image.path));
        });
        _showBillImagesPreview();
      }
    } catch (e) {
      _showSnackBar('Error accessing gallery: $e');
    }
  }
  
  void _showBillImagesPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text(
                    'Bill Images',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_billImages.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          'No bill images added',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _billImages.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(right: 16),
                            width: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    _billImages[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _billImages.removeAt(index);
                                      });
                                      setSheetState(() {});
                                      _showSnackBar('Image removed', Colors.orange);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _billImages.clear();
                            });
                            setSheetState(() {});
                            _showSnackBar('All images cleared', Colors.orange);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'CLEAR ALL',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showSnackBar('${_billImages.length} bill images saved', Colors.green);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC407A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('DONE', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _pickImageFromGallery();
                    },
                    icon: const Icon(Icons.add_photo_alternate, color: Color(0xFFEC407A)),
                    label: const Text(
                      'Add More',
                      style: TextStyle(color: Color(0xFFEC407A)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  void _showBillsSummary() {
    if (_billImages.isEmpty) {
      _showSnackBar('No bill images added', Colors.orange);
    } else {
      _showSnackBar('${_billImages.length} bill image(s) attached', Colors.green);
    }
  }

  // --- DATE & TIME PICKERS ---
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            useMaterial3: false, 
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFEC407A), 
              onPrimary: Colors.white,   
              surface: Colors.white,
              onSurface: Colors.black,   
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEC407A), 
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            useMaterial3: false, 
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFEC407A), 
              onPrimary: Colors.white,   
              surface: Colors.white,
              onSurface: Colors.black,   
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEC407A), 
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _selectedTimeOfDay = picked.format(context); 
      });
    }
  }
  
  // Category Selection Bottom Sheet
  void _showCategorySelection() {
    _searchQuery = '';
    _searchController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredCategories = _categories.where((cat) {
              return cat['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.widgets_outlined, color: Color(0xFFEC407A), size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Category',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            _showAddNewCategoryFullScreen();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC407A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Add New',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400, width: 1.1),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setSheetState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Row(
                        children: [
                          const Text(
                            'Selected: ',
                            style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEC407A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_selectedCategoryIcon, size: 16, color: const Color(0xFFEC407A)),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedCategory,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 1),
                    const SizedBox(height: 12),

                    SizedBox(
                      height: 280,
                      child: filteredCategories.isEmpty
                          ? const Center(child: Text('No categories found', style: TextStyle(color: Colors.grey)))
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const ClampingScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.95,
                              ),
                              itemCount: filteredCategories.length,
                              itemBuilder: (context, index) {
                                final cat = filteredCategories[index];
                                final isSelected = _selectedCategory == cat['name'];
                                
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = cat['name'];
                                      _selectedCategoryIcon = cat['icon'];
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: (cat['color'] as Color).withValues(alpha: 0.15),
                                        child: Icon(cat['icon'], color: cat['color'], size: 24),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        cat['name'],
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: const Color(0xFF1F2937),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFFEC407A),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Add New Category Full Screen Page
  void _showAddNewCategoryFullScreen() {
    final TextEditingController nameController = TextEditingController();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFFEFEFEF),
          appBar: AppBar(
            title: const Text(
              'Add New Category',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF141E27),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: StatefulBuilder(
            builder: (context, setPageState) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF9CA3AF), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category Name',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF141E27)),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nameController,
                            maxLength: 20,
                            style: const TextStyle(color: Color(0xFF141E27)),
                            decoration: InputDecoration(
                              hintText: 'Enter category name',
                              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF9CA3AF)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEC407A), width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Existing Categories',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 16),
                    
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: (cat['color'] as Color).withValues(alpha: 0.15),
                              child: Icon(cat['icon'], color: cat['color'], size: 24),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat['name'],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF9CA3AF), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final newName = nameController.text.trim();
                              if (newName.isNotEmpty && newName.length <= 20) {
                                bool exists = _categories.any((cat) => cat['name'].toLowerCase() == newName.toLowerCase());
                                if (exists) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Category already exists!'), backgroundColor: Colors.red),
                                  );
                                } else {
                                  final newCategory = {
                                    'name': newName,
                                    'icon': Icons.star_outline,
                                    'color': const Color(0xFFEC407A)
                                  };
                                  
                                  setState(() {
                                    _categories.add(newCategory);
                                    _selectedCategory = newName;
                                    _selectedCategoryIcon = Icons.star_outline;
                                  });
                                  
                                  _saveCategoriesToFirestore();
                                  
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Category added successfully!'), backgroundColor: Colors.green),
                                  );
                                }
                              } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter valid category name (max 20 characters)'), backgroundColor: Colors.red),
                                  );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEC407A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CalculatorBottomSheet(
          onResult: (value) {
            _amountController.text = value;
          },
        );
      },
    );
  }

  void _showSnackBar(String msg, [Color? color]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: color ?? const Color(0xFFEC407A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showReminderDialog() {
    showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030)).then((date) {
      if (date != null) _showSnackBar('Reminder set for ${DateFormat('dd/MM/yyyy').format(date)}');
    });
  }

  //Add Items
  void _showItemsDialog() {
    List<Map<String, dynamic>> itemsList = [];
    
    final TextEditingController itemController = TextEditingController();
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController unitController = TextEditingController();
    final TextEditingController rateController = TextEditingController();
    
    double totalAmount = 0.0;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              backgroundColor: Colors.white,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add Items', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    TextField(
                      controller: itemController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Pizza, Burger, Cold Drink',
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: unitController,
                            decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder(), hintText: 'pcs, kg, L'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: rateController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Rate (Rs)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          String itemName = itemController.text.trim().toLowerCase();
                          double qty = double.tryParse(quantityController.text) ?? 0;
                          double rate = double.tryParse(rateController.text) ?? 0;
                          String unit = unitController.text.trim();
                          
                          if (itemName.isEmpty) {
                            _showSnackBar('Please enter item name', Colors.red);
                            return;
                          }
                          if (qty <= 0) {
                            _showSnackBar('Please enter valid quantity', Colors.red);
                            return;
                          }
                          if (rate <= 0) {
                            _showSnackBar('Please enter valid rate', Colors.red);
                            return;
                          }
                          
                          int existingIndex = itemsList.indexWhere(
                            (item) => item['name'].toString().toLowerCase() == itemName
                          );
                          
                          if (existingIndex != -1) {
                            _showConfirmDialog(
                              context,
                              'Item Already Exists!',
                              '${itemsList[existingIndex]['name']} already added.\n\nDo you want to update quantity?',
                              () {
                                double oldTotal = itemsList[existingIndex]['total'];
                                double newTotal = qty * rate;
                                
                                setDialogState(() {
                                  itemsList[existingIndex]['qty'] = qty;
                                  itemsList[existingIndex]['rate'] = rate;
                                  itemsList[existingIndex]['unit'] = unit.isEmpty ? 'pcs' : unit;
                                  itemsList[existingIndex]['total'] = newTotal;
                                  totalAmount = totalAmount - oldTotal + newTotal;
                                });
                                
                                itemController.clear();
                                quantityController.clear();
                                unitController.clear();
                                rateController.clear();
                                
                                _showSnackBar('${itemName.toUpperCase()} updated!', Colors.green);
                              },
                            );
                          } else {
                            double itemTotal = qty * rate;
                            itemsList.add({
                              'name': itemName,
                              'displayName': itemController.text.trim(),
                              'qty': qty,
                              'unit': unit.isEmpty ? 'pcs' : unit,
                              'rate': rate,
                              'total': itemTotal
                            });
                            totalAmount += itemTotal;
                            
                            itemController.clear();
                            quantityController.clear();
                            unitController.clear();
                            rateController.clear();
                            setDialogState(() {});
                            
                            _showSnackBar('${itemController.text} added!', Colors.green);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC407A)),
                        child: const Text('ADD', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '📋 Added Items',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                'Total: Rs ${_formatAmount(totalAmount)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFEC407A)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          
                          if (itemsList.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(
                                child: Text(
                                  'No items added yet.\nAdd your first item above ☝️',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 180,
                              child: ListView.builder(
                                itemCount: itemsList.length,
                                itemBuilder: (context, index) {
                                  final item = itemsList[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    elevation: 2,
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFFEC407A).withValues(alpha: 0.1),
                                        radius: 18,
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(color: Color(0xFFEC407A), fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                      title: Text(
                                        item['displayName'] ?? item['name'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        '${_formatAmountDouble(item['qty'])} ${item['unit']} × Rs ${_formatAmountDouble(item['rate'])}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Rs ${_formatAmount(item['total'])}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                            onPressed: () {
                                              totalAmount -= item['total'];
                                              itemsList.removeAt(index);
                                              setDialogState(() {});
                                              _showSnackBar('Item removed', Colors.orange);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            if (itemsList.isNotEmpty) {
                              _showConfirmDialog(
                                context,
                                'Clear All Items?',
                                'This will remove all ${itemsList.length} items from the list.',
                                () {
                                  itemsList.clear();
                                  totalAmount = 0;
                                  setDialogState(() {});
                                  _showSnackBar('All items cleared', Colors.orange);
                                },
                              );
                            }
                          },
                          child: const Text('CLEAR ALL', style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('CANCEL', style: TextStyle(color: Color(0xFFEC407A))),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (itemsList.isEmpty) {
                              _showSnackBar('Please add at least one item', Colors.red);
                              return;
                            }
                            _amountController.text = _formatAmount(totalAmount);
                            Navigator.pop(dialogContext);
                            _showSnackBar('${itemsList.length} items added! Total: Rs ${_formatAmount(totalAmount)}', Colors.green);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC407A)),
                          child: const Text('OK', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper Functions
  String _formatAmount(double amount) {
    if (amount == amount.toInt()) {
      return amount.toInt().toString();
    } else {
      return amount.toStringAsFixed(2);
    }
  }

  String _formatAmountDouble(double amount) {
    if (amount == amount.toInt()) {
      return amount.toInt().toString();
    } else {
      return amount.toStringAsFixed(2);
    }
  }

  void _showConfirmDialog(BuildContext context, String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('NO', style: TextStyle(color: Color(0xFFEC407A))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('YES', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveIncome() async {
    final String amount = _amountController.text.trim();
    if (amount.isEmpty || double.tryParse(amount) == null || double.parse(amount) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red));
      return;
    }
    if (_currentUserId == null) return;

    setState(() => _isLoading = true);
    try {
      final DateTime fullDateTime = DateTime(
        _selectedDate.year, 
        _selectedDate.month, 
        _selectedDate.day, 
        _selectedTime.hour, 
        _selectedTime.minute
      );
      
      await _firestore.collection('transactions').add({
        'userId': _currentUserId,
        'amount': double.parse(amount),
        'category': _selectedCategory,
        'type': 'income',
        'paymentMethod': _selectedPaymentMethod,
        'description': _notesController.text.trim().isEmpty ? 'Income' : _notesController.text.trim(),
        'date': Timestamp.fromDate(fullDateTime),
        'isRecurring': _isRecurring,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      
      appBar: AppBar(
        title: const Text(
          'Add Income',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF141E27), 
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_billImages.isNotEmpty)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.receipt, color: Colors.white),
                  onPressed: _showBillsSummary,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEC407A),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_billImages.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Income Field - BORDER REMOVED
              const Text(
                'Income',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF141E27)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                autofocus: true, 
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF141E27)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  prefixText: 'Rs ',
                  prefixStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF141E27)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calculate_outlined, color: Color(0xFFEC407A), size: 24),
                    onPressed: () {
                      FocusScope.of(context).unfocus(); 
                      _showCalculator();
                    },
                  ),
                  // ✅ BORDER REMOVED
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),

              // Category Selection
              const Text(
                'Category',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF141E27)),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showCategorySelection,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    // border: Border.all(color: const Color(0xFF9CA3AF), width: 1.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFEC407A).withValues(alpha: 0.1),
                        child: Icon(_selectedCategoryIcon, color: const Color(0xFFEC407A), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _selectedCategory,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF141E27)),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFFEC407A)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Payment Method
              const Text(
                'Payment Method',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF141E27)),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showPaymentMethodSelection,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    // border: Border.all(color: const Color(0xFF9CA3AF), width: 1.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFEC407A).withValues(alpha: 0.1),
                        child: Icon(Icons.payment, color: const Color(0xFFEC407A), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _selectedPaymentMethod,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF141E27)),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFFEC407A)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes Field - BORDER REMOVED
              const Text(
                'Notes (Optional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF141E27)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(color: Color(0xFF141E27)),
                decoration: InputDecoration(
                  hintText: 'Add a note...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: Colors.white,
                  // ✅ BORDER REMOVED
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),

              // Add Bills & Add Items
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showAddBillsDialog,
                      icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFFEC407A)),
                      label: const Text('Add Bills', style: TextStyle(color: Color(0xFF141E27), fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF9CA3AF), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showItemsDialog,
                      icon: const Icon(Icons.list_alt_rounded, color: Color(0xFFEC407A)),
                      label: const Text('Add Items', style: TextStyle(color: Color(0xFF141E27), fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        // side: const BorderSide(color: Color(0xFF9CA3AF), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date & Time
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        // border: Border.all(color: const Color(0xFF9CA3AF), width: 1.0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black),
                            onPressed: () {
                              setState(() {
                                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                              });
                            },
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: _selectDate,
                              child: Center(
                                child: Text(
                                  DateFormat('dd-MMM-yyyy').format(_selectedDate),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
                            onPressed: () {
                              setState(() {
                                _selectedDate = _selectedDate.add(const Duration(days: 1));
                              });
                            },
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.calendar_month, color: Color(0xFFEC407A), size: 22),
                            onPressed: _selectDate,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _selectTime,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          // border: Border.all(color: const Color(0xFF9CA3AF), width: 1.0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedTimeOfDay,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black),
                            ),
                            const Icon(Icons.access_time_filled, color: Color(0xFFEC407A), size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Recurring
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  // border: Border.all(color: const Color(0xFF9CA3AF), width: 1.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  title: const Text("Recurring? Set Reminder", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF141E27))),
                  value: _isRecurring,
                  activeColor: const Color(0xFFEC407A),
                  onChanged: (v) => setState(() => _isRecurring = v ?? false),
                  secondary: IconButton(
                    icon: const Icon(Icons.notifications_active, color: Color(0xFFEC407A)),
                    onPressed: _showReminderDialog,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4)),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveIncome,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC407A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'SAVE',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// Calculator Bottom Sheet
class _CalculatorBottomSheet extends StatefulWidget {
  final Function(String) onResult;
  const _CalculatorBottomSheet({required this.onResult});

  @override
  State<_CalculatorBottomSheet> createState() => _CalculatorBottomSheetState();
}

class _CalculatorBottomSheetState extends State<_CalculatorBottomSheet> {
  String _expression = '';
  String _result = '0';
  
  void _append(String val) {
    setState(() {
      _expression += val;
      _calculate();
    });
  }
  
  void _clear() {
    setState(() {
      _expression = '';
      _result = '0';
    });
  }
  
  void _calculate() {
    if (_expression.isEmpty) {
      _result = '0';
      return;
    }
    try {
      String cleanExp = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      if (RegExp(r'[+\-*/]$').hasMatch(cleanExp)) {
        return;
      }
      
      List<String> tokens = [];
      String current = '';
      for (int i = 0; i < cleanExp.length; i++) {
        if (cleanExp[i] == '+' || cleanExp[i] == '-' || cleanExp[i] == '*' || cleanExp[i] == '/') {
          if (current.isNotEmpty) {
            tokens.add(current);
            current = '';
          }
          tokens.add(cleanExp[i]);
        } else {
          current += cleanExp[i];
        }
      }
      if (current.isNotEmpty) {
        tokens.add(current);
      }
      
      if (tokens.isEmpty) {
        return;
      }
      
      double res = double.parse(tokens[0]);
      for (int i = 1; i < tokens.length; i += 2) {
        double next = double.parse(tokens[i + 1]);
        String op = tokens[i];
        if (op == '+') {
          res += next;
        } else if (op == '-') {
          res -= next;
        } else if (op == '*') {
          res *= next;
        } else if (op == '/') {
          res /= next;
        }
      }
      _result = res.toStringAsFixed(res == res.toInt() ? 0 : 2);
    } catch (_) {
      _result = 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _expression.isEmpty ? '0' : _expression,
                    style: const TextStyle(fontSize: 18, color: Color(0xFF6B7280)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _result,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF141E27)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              Row(
                children: [
                  _calcBtn('7', Colors.grey.shade100, const Color(0xFF141E27)),
                  _calcBtn('8', Colors.grey.shade100, const Color(0xFF141E27)),
                  _calcBtn('9', Colors.grey.shade100, const Color(0xFF141E27)),
                  _calcBtn('÷', const Color(0xFFEC407A), Colors.white),
                ],
              ),
              Row(
                children: [
                  _calcBtn('4', Colors.grey.shade100, const Color(0xFF141E27)),
                  _calcBtn('5', Colors.grey.shade100, const Color(0xFF141E27)),
                  _calcBtn('6', Colors.grey.shade100, const Color(0xFF141E27)),
                  _calcBtn('×', const Color(0xFFEC407A), Colors.white),
                ],
              ),
              Row(
                children: [
                  _calcBtn('1', Colors.grey.shade100, const Color(0xFF141E27)),
                  _calcBtn('2', Colors.grey.shade100, const Color(0xFF141E27)),
                  _calcBtn('3', Colors.grey.shade100, const Color(0xFF141E27)),
                  _calcBtn('-', const Color(0xFFEC407A), Colors.white),
                ],
              ),
              Row(
                children: [
                  _calcBtn('C', Colors.red.shade100, Colors.red),
                  _calcBtn('0', Colors.grey.shade100, const Color(0xFF141E27)),
                  _calcBtn('.', Colors.grey.shade100, const Color(0xFF141E27)),
                  _calcBtn('+', const Color(0xFFEC407A), Colors.white),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC407A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                if (_result != 'Error') {
                  widget.onResult(_result);
                  Navigator.pop(context);
                }
              },
              child: const Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _calcBtn(String text, Color bgColor, Color textColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: InkWell(
          onTap: () {
            if (text == 'C') {
              _clear();
            } else if (text == '÷') {
              _append('/');
            } else if (text == '×') {
              _append('*');
            } else {
              _append(text);
            }
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
