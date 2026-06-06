import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../utils/colors.dart';

// ignore_for_file: prefer_final_fields, prefer_const_constructors, unused_field, unused_element


class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
final TextEditingController _expenseController = TextEditingController();
final TextEditingController _notesController = TextEditingController(); 
final TextEditingController _searchController = TextEditingController();
final TextEditingController _paymentSearchController = TextEditingController();

  String? _expenseErrorText;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final firebase_storage.FirebaseStorage _storage = firebase_storage.FirebaseStorage.instance;

  String? get _currentUserId => _auth.currentUser?.uid;
  
  
  // Current balance from Firebase
  double _currentBalance = 0.0;
  bool _isLoading = false;

  // Reminder variables
DateTime? _selectedReminderDate;
bool _isRecurring = false;
String _reminderText = ''; 

  // Date & Time variables
DateTime _selectedDate = DateTime.now();
TimeOfDay _selectedTime = TimeOfDay.now();
String _selectedTimeOfDay = '';

  // Bills images list
  List<File> _billImages = [];
  
// Add Items variables
List<Map<String, dynamic>> _itemsList = [];
double _itemsTotalAmount = 0.0;

  // Payment method variables

   String _selectedPaymentMethod = 'Cash';
  double _selectedPaymentMethodBalance = 0.0;
   List<Map<String, dynamic>> _paymentMethodsList = [
    {'name': 'Cash', 'balance': 0.0},
    {'name': 'Bank', 'balance': 0.0},
    {'name': 'Credit Card', 'balance': 0.0},
    {'name': 'Debit Card', 'balance': 0.0},
    {'name': 'Mobile Wallet', 'balance': 0.0},
    {'name': 'Other', 'balance': 0.0},
  ];
  String _searchPaymentQuery = '';

   // Category variables
  String _selectedCategory = 'food';
  IconData _selectedCategoryIcon = Icons.category;
  List<Map<String, dynamic>> _categories = [
    {'name': 'Food', 'icon': Icons.restaurant, 'color': const Color(0xFFFBBF24)},
    {'name': 'Transport', 'icon': Icons.directions_car, 'color': const Color(0xFF60A5FA)},
    {'name': 'Shopping', 'icon': Icons.shopping_bag, 'color': const Color(0xFFF87171)},
    {'name': 'Entertainment', 'icon': Icons.movie, 'color': const Color(0xFFF472B6)},
    {'name': 'Healthcare', 'icon': Icons.health_and_safety, 'color': const Color(0xFF34D399)},
    {'name': 'Bills', 'icon': Icons.receipt, 'color': const Color(0xFFFB7185)},
  ];
  

  // Colors ab AppColors se le rahe hain
  final Color primaryBg = AppColors.background;  
  final Color appBarColor = const Color(0xFF141E27);
  final Color saveButtonColor = AppColors.primaryPink;  
  final Color textDark = AppColors.textDark;  
  final Color textLight = Colors.white;
  final Color labelColorRed = Colors.red;

  final ImagePicker _imagePicker = ImagePicker();


   @override
    void initState() {
    super.initState();
    _loadCurrentBalance();  
    _loadCategoriesFromFirestore();
    _loadPaymentMethodsFromFirestore();
    _selectedTimeOfDay = _formatTimeOfDay(TimeOfDay.now());


  }

  @override
  void dispose() {
    _expenseController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    _paymentSearchController.dispose();
    super.dispose();
  }

// Upload images to Firebase Storage
Future<List<String>> _uploadBillImages() async {
    List<String> imageUrls = [];
    
    for (File image in _billImages) {
      try {
        String fileName = 'expense_bills/$_currentUserId/${DateTime.now().millisecondsSinceEpoch}_${image.hashCode}.jpg';
        firebase_storage.UploadTask uploadTask = _storage.ref(fileName).putFile(image);
        firebase_storage.TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      } catch (e) {
        _showSnackBar('Error uploading image: $e', Colors.red);
      }
    }
    
    return imageUrls;
  }
// Add Item
void _showItemsDialog() {
  final TextEditingController itemController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController rateController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            backgroundColor: Colors.white,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.95,
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add Items', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    // Item Name
                    TextField(
                      controller: itemController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Quantity, Unit, Rate Row
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
                            decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder(), hintText: 'kg, L, pcs'),
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
                    
                    // ADD Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          String itemName = itemController.text.trim();
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
                          
                          double itemTotal = qty * rate;
                          
                          setDialogState(() {
                            _itemsList.add({
                              'name': itemName,
                              'qty': qty,
                              'unit': unit.isEmpty ? 'pcs' : unit,
                              'rate': rate,
                              'total': itemTotal
                            });
                            _itemsTotalAmount += itemTotal;
                          });
                          
                          setState(() {
                            _expenseController.text = _itemsTotalAmount.toStringAsFixed(0);
                          });
                          
                          itemController.clear();
                          quantityController.clear();
                          unitController.clear();
                          rateController.clear();
                          _showSnackBar('$itemName added!', Colors.green);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC407A)),
                        child: const Text('ADD', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    
                    // 🌟 CHANGING 1: Agar items empty hain to spacing aur box dono gayab ho jayenge
                    if (_itemsList.isNotEmpty) ...[
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
                                const Text('📋 Added Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(
                                  'Total: Rs ${_formatAmount(_itemsTotalAmount)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFEC407A)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 180,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _itemsList.length,
                                itemBuilder: (context, index) {
                                  final item = _itemsList[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    elevation: 1,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFFEC407A).withValues(alpha: 0.1),
                                        radius: 16,
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(color: Color(0xFFEC407A), fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ),
                                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      subtitle: Text(
                                        '${_formatAmountDouble(item['qty'])} ${item['unit']} × Rs ${_formatAmountDouble(item['rate'])}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Rs ${_formatAmount(item['total'])}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            onPressed: () {
                                              setDialogState(() {
                                                _itemsTotalAmount -= item['total'];
                                                _itemsList.removeAt(index);
                                              });
                                              setState(() {
                                                _expenseController.text = _itemsTotalAmount == 0 ? '' : _itemsTotalAmount.toStringAsFixed(0);
                                              });
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
                    ],
                    
                    const SizedBox(height: 20),
                    
                    // Buttons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 🌟 CHANGING 2: CLEAR ALL BUTTON KO PERMANENTLY REMOVE KAR DIYA
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('CANCEL', style: TextStyle(color: Color(0xFFEC407A))),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (_itemsList.isEmpty) {
                              _showSnackBar('Please add at least one item', Colors.red);
                              return;
                            }
                            Navigator.pop(dialogContext);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC407A)),
                          child: const Text('OK', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// Helper Functions for formatting
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

String _formatTimeOfDay(TimeOfDay time) {
  final now = DateTime.now();
  final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  return DateFormat('hh:mm a').format(dt);
}

 // Add Bills Dialog
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

// Recurring

Future<void> _selectReminderDate() async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: _selectedReminderDate ?? DateTime.now(),
    firstDate: DateTime.now(),
    lastDate: DateTime(2030),
    helpText:_selectedDate.year.toString(),  // Upar ka text aur space khatam
    cancelText: 'CANCEL',
    confirmText: 'OK',
    builder: (context, child) {
      return Theme(
        data: ThemeData.light(useMaterial3: false).copyWith( // Header ko pink aur text ko white karne ke liye
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFEC407A),       // Pink header & selected circle
            onPrimary: Colors.white,          // White text
            onSurface: Color(0xFF141E27),     // Dark text
            surface: Colors.white,            // Dialog background
          ),

          hoverColor: Colors.transparent,       // Mouse pointer ya long press ka grey color khatam
          splashColor: Colors.transparent,      // Click karte waqt ka grey circle khatam
          highlightColor: Colors.transparent,
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEC407A), // Cancel/OK buttons pink
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 5), // Buttons ki padding kam ki
            ),
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
          ),
        ),
        // 🌟 YAHAN MEDIAQUERY USE KI HAI SPACE KHATAM KARNE KE LIYE
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // Is se calendar ka content tight ho jata hai aur faltu space squeeze ho jati hai
            viewInsets: EdgeInsets.zero, 
          ),
          child: Builder(
            builder: (context) {
              // ConstrainedBox ke zariye hum ne height ko bilkul fit (wrap) kar diya hai
              return ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 280, // Calendar ki height lock kar di taake extra space na bane
                ),
                child: child!,
              );
            },
          ),
        ),
      );
    },
  );
  
  if (picked != null) {
    setState(() {
      _selectedReminderDate = picked;
      _isRecurring = true;
      _reminderText = DateFormat('dd-MMM-yyyy').format(picked);
    });
  }
}

 // YAHAN CHANGE 5: Pick Image from Camera
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
              // 🌟 CHANGE 1: Content ko scrollable kiya taake kisi bhi phone par overflow error na aaye
              child: SingleChildScrollView( 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext dialogContext) {
                                            return AlertDialog(
                                              title: const Text(
                                                'Are you Sure?',
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              content: const Text('Do you really want to remove this bill image?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(dialogContext).pop();
                                                  },
                                                  child: const Text(
                                                    'Cancel',
                                                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(dialogContext).pop();
                                                    setState(() {
                                                      _billImages.removeAt(index);
                                                    });
                                                    setSheetState(() {});
                                                    _showSnackBar('Image removed', Colors.orange);
                                                  },
                                                  child: const Text(
                                                    'Yes',
                                                    style: TextStyle(color: Color(0xFFEC407A), fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
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
                              // 🌟 CHANGE 2: CLEAR ALL par bhi confirmation dialog laga diya taake safe deletion ho
                              if (_billImages.isEmpty) return; // Agar pehle hi khali hai to popup na khule
                              showDialog(
                                context: context,
                                builder: (BuildContext dialogContext) {
                                  return AlertDialog(
                                    title: const Text('Clear All Images?', style: TextStyle(fontWeight: FontWeight.bold)),
                                    content: const Text('Are you sure you want to delete all added bill images?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(),
                                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(dialogContext).pop();
                                          setState(() {
                                            _billImages.clear();
                                          });
                                          setSheetState(() {});
                                          _showSnackBar('All images cleared', Colors.orange);
                                        },
                                        child: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  );
                                },
                              );
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
                    
                    // ADD MORE BUTTON (Full Width)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
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
                    ),
                    
                    const SizedBox(height: 10),
                  ],
                ),
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

  void _showSnackBar(String msg, [Color? color]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: color ?? const Color(0xFFEC407A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Date Picker
  Future<void> _selectDate() async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: _selectedDate,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
     helpText: _selectedDate.year.toString(),
    builder: (context, child) {
      return Theme(
       data: ThemeData.light(useMaterial3: false).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFEC407A),
            onPrimary: Colors.white,
            onSurface: Color(0xFF141E27),
          ),

           hoverColor: Colors.transparent,       // Mouse pointer ya long press ka grey color khatam
          splashColor: Colors.transparent,      // Click karte waqt ka grey circle khatam
          highlightColor: Colors.transparent,

          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEC407A),
               padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 5),
            ),
          ),
          dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),

            ),
          ),
        ),

        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: EdgeInsets.zero, 
          ),
          child: Builder(
            builder: (context) {
              return ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 280, // Calendar ki height lock
                ),
        child: child!,
      );
    },
  ),
),
      );
      },
      ); 
  
  if (picked != null && picked != _selectedDate) {
    setState(() {
      _selectedDate = picked;
    });
  }
}

// Time Picker
Future<void> _selectTime() async {
  final TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
    initialEntryMode: TimePickerEntryMode.dialOnly,
    helpText: '',
    builder: (context, child) {
      return Theme(
        data: ThemeData.light(useMaterial3: false).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFEC407A),       // Header background pink
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF141E27),
          ),
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          
          timePickerTheme: TimePickerThemeData(
            backgroundColor: Colors.white,
            dialHandColor: const Color(0xFFEC407A),
            dialBackgroundColor: const Color(0xFFF3F4F6),
            dialTextColor: const Color(0xFF141E27),
            dayPeriodBorderSide: const BorderSide(color: Color(0xFFEC407A), width: 1),
            dayPeriodColor: WidgetStateColor.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFFEC407A).withValues(alpha: 0.2);
              }
              return Colors.white;
            }),
            dayPeriodTextColor: const Color(0xFF141E27),
            hourMinuteColor: const Color(0xFFF3F4F6),
            hourMinuteTextColor: const Color(0xFF141E27),
          ),
          
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEC407A),
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          
          dialogTheme: const DialogThemeData(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
          ),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: EdgeInsets.zero,
            alwaysUse24HourFormat: false,
          ),
          child: child!,
        ),
      );
    },
  );

  if (picked != null) {
    setState(() {
      _selectedTimeOfDay = picked.format(context);
    });
  }
}

 // Payment methods Firestore
 Future<void> _loadPaymentMethodsFromFirestore() async {
    if (_currentUserId == null) return;
    
    try {
      final doc = await _firestore.collection('user_payment_methods').doc(_currentUserId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> savedMethods = data['paymentMethods'] ?? [];
        
        if (savedMethods.isNotEmpty) {
          setState(() {
            _paymentMethodsList = savedMethods.cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (e) {
      // print('Error loading payment methods: $e');
    }
  }

  // Payment methods Firestore mein save karne ka function
  Future<void> _savePaymentMethodsToFirestore() async {
    if (_currentUserId == null) return;
    
    try {
      await _firestore.collection('user_payment_methods').doc(_currentUserId).set({
        'paymentMethods': _paymentMethodsList,
      });
    } catch (e) {
      // print('Error saving payment methods: $e');
    }
  }

  // Payment method selection modal
  void _showPaymentMethodSelection() {
  _searchPaymentQuery = '';
  _paymentSearchController.clear();

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
          final filteredMethods = _paymentMethodsList.where((method) {
  return method['name'].toString().toLowerCase().contains(_searchPaymentQuery.toLowerCase());
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Notch/Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Row
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, color: saveButtonColor, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Payment Method',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddNewPaymentMethodDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: saveButtonColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Add New', 
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: saveButtonColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: TextField(
                      controller: _paymentSearchController,
                      onChanged: (value) {
                        setSheetState(() {
                          _searchPaymentQuery = value;
                        });
                      },
                      cursorColor: saveButtonColor, // Pink cursor
                      style: TextStyle(color: textDark),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search, color: saveButtonColor, size: 22),
                        hintText: 'Search payment method...',
                        hintStyle: TextStyle(color: textDark.withValues(alpha: 0.4), fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        
                        // Normal condition me borderless clean look
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        
                        // 🔴 FIXED: Search par click karte hi active hone wala Premium Pink Border
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: saveButtonColor, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment Methods List
                  // FIXED: Flexible aur ConstrainedBox lagaya taake keyboard open hone par screen text overflow na kare
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: filteredMethods.isEmpty
                          ? const Center(child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text('No payment methods found', style: TextStyle(color: Colors.grey)),
                            ))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredMethods.length,
                              itemBuilder: (context, index) {
                                final method = filteredMethods[index];
                                return Column(
                                  children: [
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                      title: Text(
                                        method['name'],style: TextStyle(fontSize: 16, color: textDark, fontWeight: FontWeight.w500),
                                      ),
                                      trailing: _selectedPaymentMethod == method['name']  
                                          ? Icon(Icons.check_circle, color: saveButtonColor, size: 20)
                                          : null,
                                      onTap: () {
                                        setState(() {
                                          _selectedPaymentMethod = method['name'];
                                        });
                                        Navigator.pop(context);
                                      },
                                    ),
                                    Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
                                  ],
                                );
                              },
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

  // Add new payment method dialog
  void _showAddNewPaymentMethodDialog() {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();
  bool isPositive = true;
  // 🔴 SELECTED DATE STATE VARIABLE
  DateTime selectedDate = DateTime.now();

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // Boxy look matching your image
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
                    style: const TextStyle(color: Color(0xFF141E27)),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                      floatingLabelStyle: const TextStyle(color: Color(0xFFEC407A)), // Pink on Focus
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFEC407A), width: 1.5), // Pink on Focus
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
                    style: const TextStyle(color: Color(0xFF141E27)),
                    decoration: InputDecoration(
                      labelText: 'Opening Balance [Optional]',
                      labelStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                      floatingLabelStyle: const TextStyle(color: Color(0xFFEC407A)), // Pink on Focus
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFEC407A), width: 1.5), // Pink on Focus
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

                  // 🔴 FIXED: Fully Working Calendar Date Picker Display Field
                  GestureDetector(
  onTap: () async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      helpText: selectedDate.year.toString(), // 🌟 Same year text help jesa look
      builder: (context, child) {
        return Theme(
          data: ThemeData.light(useMaterial3: false).copyWith( // 🌟 Material 2 look look lock kiya
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFEC407A), // Muted Pink Accent
              onPrimary: Colors.white,
              onSurface: Color(0xFF141E27),
            ),
            hoverColor: Colors.transparent,       // Long press grey color khatam
            splashColor: Colors.transparent,      // Click splash grey circle khatam
            highlightColor: Colors.transparent,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEC407A),
                padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 5),
              ),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: EdgeInsets.zero,
            ),
            child: Builder(
              builder: (context) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 280, // 🌟 Same exact height restriction
                  ),
                  child: child!,
                );
              },
            ),
          ),
        );
      },
    );
    
    // Dialog ke state sync ke liye variable name badal kar setDialogState lagaya
    if (pickedDate != null && pickedDate != selectedDate) {
      setDialogState(() {
        selectedDate = pickedDate; 
      });
    }
  },
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade400),
      borderRadius: BorderRadius.circular(4),
      color: Colors.white,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('dd-MMM-yyyy').format(selectedDate), 
          style: const TextStyle(fontSize: 16, color: Colors.black),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.calendar_month, color: Color(0xFFEC407A)),
      ],
    ),
  ),
)
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
                    double openingBalance = double.tryParse(balanceController.text) ?? 0;
                     if (!isPositive) {
        openingBalance = -openingBalance;
      }

      // ✅ STEP 3: Check for duplicate payment method
      bool exists = _paymentMethodsList.any(
  (method) => method['name'].toString().toLowerCase() == newName.toLowerCase()
      );
      
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment method already exists!'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        // ✅ STEP 4: Add new payment method
        setState(() {
_paymentMethodsList.add({
  'name': newName,
  'balance': openingBalance,
});          _selectedPaymentMethod = newName;
        });
        
        // ✅ STEP 5: Save to Firestore
        _savePaymentMethodsToFirestore(); 
        
        // ✅ STEP 6: Show success message with balance
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$newName" added with balance: ${_formatAmount(openingBalance)}'),
            backgroundColor: Colors.green,
          ),
        );

                    Navigator.pop(context);
                  }
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

  // Load categories from Firestore
  Future<void> _loadCategoriesFromFirestore() async {
    if (_currentUserId == null) return;
    
    try {
      final doc = await _firestore.collection('expense_categories').doc(_currentUserId).get();
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
      
      await _firestore.collection('expense_categories').doc(_currentUserId).set({
        'categories': categoriesToSave,
      });
    } catch (e) {
      // print('Error saving categories: $e');
    }
  }

  // Convert IconData to String
  String _getIconString(IconData icon) {
    if (icon == Icons.restaurant) return 'restaurant';
    if (icon == Icons.directions_car) return 'directions_car';
    if (icon == Icons.shopping_bag) return 'shopping_bag';
    if (icon == Icons.movie) return 'movie';
    if (icon == Icons.health_and_safety) return 'health_and_safety';
    if (icon == Icons.receipt) return 'receipt';
    if (icon == Icons.category) return 'category';
    if (icon == Icons.star_outline) return 'star_outline';
    return 'category';
  }

  // Convert String to IconData
  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'restaurant': return Icons.restaurant;
      case 'directions_car': return Icons.directions_car;
      case 'shopping_bag': return Icons.shopping_bag;
      case 'movie': return Icons.movie;
      case 'health_and_safety': return Icons.health_and_safety;
      case 'receipt': return Icons.receipt;
      case 'category': return Icons.category;
      case 'star_outline': return Icons.star_outline;
      default: return Icons.category;
      
    }
  }

  // Show category selection modal
  void _showCategorySelection() {
  String searchQuery = '';
  
  // CHANGED: showModalBottomSheet ki jagah showGeneralDialog lagaya taake animation 0 (disabled) ho sake
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.5), // Background dim effect
    transitionDuration: Duration.zero, // 🔴 FIXED: Animation bilkul khatam! Foran khulega bina move kiye
    pageBuilder: (context, anim1, anim2) {
      return Align(
        alignment: Alignment.bottomCenter, // Screen ke bottom par chipka rahega
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredCategories = _categories.where((cat) {
              return cat['name'].toString().toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Material(
              color: Colors.transparent,
              child: Container(
                // CHANGED: Top corners rounded baki screen theme se match karne ke liye
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: EdgeInsets.only(
                  top: 16, 
                  left: 16, 
                  right: 16, 
                  // FIXED: Keyboard aane par bottom padding smoothly auto-adjust hogi
                  bottom: MediaQuery.of(context).viewInsets.bottom + 10, 
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Notch/Handle
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
                    
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.category, color: saveButtonColor, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Category',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {
                             _showAddNewCategoryFullScreen();

                              },
                              style: ElevatedButton.styleFrom(
    backgroundColor: saveButtonColor,
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    elevation: 0,
  ),
  child: const Text('Add New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
),    
            ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Search Input Field
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: saveButtonColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setSheetState(() {
                            searchQuery = value;
                          });
                        },
                        cursorColor: saveButtonColor, // Pink cursor on click
                        style: TextStyle(color: textDark),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(color: textDark.withValues(alpha: 0.4), fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: saveButtonColor, size: 20), // 🔴 FIXED: Icon color Pink kiya
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          // 🔴 FIXED: Search field par click karne se border PINK dikhega
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: saveButtonColor, width: 1.5), // Pink border line on focus
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Selected Badge Area
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
                              color: saveButtonColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_selectedCategoryIcon, size: 16, color: saveButtonColor),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedCategory,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
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
                    
                    // Categories Grid
                    // FIXED: Flexible lagaya aur height restriction ko auto-adjust kiya taake keyboard aane par 13px overflow na ho
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280), // Maximum height limits control
                        child: filteredCategories.isEmpty
                            ? const Center(child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text('No categories found', style: TextStyle(color: Colors.grey)),
                              ))
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(), // Safe scrolling layout
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
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      setState(() {
                                        _selectedCategory = cat['name'];
                                        _selectedCategoryIcon = cat['icon'];
                                      });
                                      // Navigator.pop(context);
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
                                            color: textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    
                    // Cancel Button
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: saveButtonColor, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
  // Add new category dialog
  void _showAddNewCategoryDialog() {
  final TextEditingController nameController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add New Category',
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold, 
            color: appBarColor, // Main Dark Color
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter category name',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 12),
            
            // Input TextField
            Container(
  decoration: BoxDecoration(
    color: Colors.white, // Pure white background
    borderRadius: BorderRadius.circular(8), // Standard smooth corners
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03), // Halka sa floating premium touch
        blurRadius: 4,
        offset: const Offset(0, 2),
      )
    ],
  ),
  child: TextField(
    controller: nameController,
    autofocus: true,
    cursorColor: saveButtonColor,
    maxLength: 20,
    style: TextStyle(color: textDark, fontSize: 16),
    decoration: InputDecoration(
      hintText: 'e.g., Grocery, Rent, etc.',
      hintStyle: TextStyle(color: textDark.withValues(alpha: 0.3), fontSize: 14),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      
      // Normal halat me koi border nahi hoga taake clean look aaye
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      
      // Click hone par smart FinSight theme ka Pink border show hoga
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: saveButtonColor, width: 1.5),
      ),
    ),
  ),
),
const SizedBox(height: 20),

            Text(
              'Existing Categories:',
              style: TextStyle(color: textDark.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 34,
              child: _categories.isEmpty
                  ? const Text('No categories yet', style: TextStyle(color: Colors.grey, fontSize: 12))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20), // Pill Shape
                            border: Border.all(color: Colors.grey.shade300, width: 0.5)
                          ),
                          child: Row(
                            children: [
                              Icon(cat['icon'] as IconData, size: 14, color: cat['color'] as Color),
                              const SizedBox(width: 6),
                              Text(
                                cat['name'].toString(),
                                style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && newName.length <= 20) {
                bool exists = _categories.any(
                  (cat) => cat['name'].toLowerCase() == newName.toLowerCase()
                );
                
                if (exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category already exists!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  final newCategory = {
                    'name': newName,
                    'icon': Icons.star_outline,
                    'color': saveButtonColor
                  };
                  
                  setState(() {
                    _categories.add(newCategory);
                    _selectedCategory = newName;
                    _selectedCategoryIcon = Icons.star_outline;
                  });
                  
                  _saveCategoriesToFirestore();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"$newName" category added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid category name (max 20 characters)'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: saveButtonColor,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              elevation: 0,
            ),
            child: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
        backgroundColor: const Color(0xFFF3F4F6),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input Field Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    ),
                    child: TextField(
                      controller: nameController,
                      maxLength: 20,
                      cursorColor: const Color(0xFFEC407A),
                      style: const TextStyle(color: Color(0xFF141E27)),
                      decoration: InputDecoration(
                        labelText: 'Category Name',
                        labelStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                        floatingLabelStyle: const TextStyle(color: Color(0xFFEC407A)),
                        hintText: 'e.g., Fuel, Clothes, Rent',
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                        counterText: '',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEC407A), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Existing Categories',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF141E27)),
                  ),
                  const SizedBox(height: 16),
                  
                  // 🌟 FIXED GridView Area
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
                      final Color itemColor = cat['color'] as Color;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: itemColor.withValues(alpha: 0.15), // 👈 100% Fixed Pastel Background
                            child: Icon(
                              cat['icon'] as IconData, 
                              color: itemColor, 
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat['name'].toString(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF141E27),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF141E27), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Cancel', 
                            style: TextStyle(color: Color(0xFF141E27), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final newName = nameController.text.trim();
                            if (newName.isNotEmpty && newName.length <= 20) {
                              bool exists = _categories.any((cat) => cat['name'].toString().toLowerCase() == newName.toLowerCase());
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
                                
                                setPageState(() {
                                  _categories.add(newCategory);
                                });
                                
                                setState(() {
                                  _selectedCategory = newName;
                                  _selectedCategoryIcon = Icons.star_outline;
                                });
                                
                                _saveCategoriesToFirestore();
                                Navigator.pop(context);
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('"$newName" added successfully!'), 
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter valid category name'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC407A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Save', 
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
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
  // Get current balance from Firestore
  Future<double> _getCurrentBalance() async {
    if (_currentUserId == null) return 0.0;
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: _currentUserId)
          .get();
      double balance = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();
        final type = data['type'] ?? '';
        if (type == 'income') {
          balance += amount;
        } else if (type == 'expense') {
          balance -= amount;
        }
      }
      return balance;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _loadCurrentBalance() async {
    _currentBalance = await _getCurrentBalance();
    if (mounted) setState(() {});
  }

  // Validation and Save Logic 
  Future<void> _validateAndSave() async {
  final String inputText = _expenseController.text.trim();

  if (inputText.isEmpty) {
    setState(() {
      _expenseErrorText = "Amount should not be empty";
    });
    return;
  }

  final double? enteredAmount = double.tryParse(inputText);

   if (enteredAmount == null || enteredAmount <= 0) {
    setState(() {
      _expenseErrorText = "Amount should be a positive number";
    });
    return;
  }


    setState(() {
      _expenseErrorText = null;
      _isLoading = true;
    });

    if (_currentUserId == null) return;

    try {
      List<String> imageUrls = [];
      if (_billImages.isNotEmpty) {
        _showSnackBar('Uploading ${_billImages.length} images...', Colors.orange);
        imageUrls = await _uploadBillImages();
      }

      // ========== ✅ YEH CODE ADD KARO (Payment method balance update) ==========
  // Find payment method index
  int index = _paymentMethodsList.indexWhere(
    (method) => method['name'] == _selectedPaymentMethod
  );
  
  double newBalance = 0.0;
  if (index != -1) {
    double currentBalance = _paymentMethodsList[index]['balance'];
    newBalance = currentBalance - enteredAmount; // Expense: minus
    setState(() {
      _paymentMethodsList[index]['balance'] = newBalance;
    });
    _savePaymentMethodsToFirestore(); // Save updated balance to Firestore
  }
      
  final DateTime fullDateTime = DateTime(
  _selectedDate.year,
  _selectedDate.month,
  _selectedDate.day,
  _selectedTime.hour,
  _selectedTime.minute,
);
      await _firestore.collection('transactions').add({
        'userId': _currentUserId,
        'amount': enteredAmount,
        'category': _selectedCategory,
        'type': 'expense',
        'paymentMethod': _selectedPaymentMethod,
        'paymentMethodBalance': newBalance,
        'description': _notesController.text.trim().isEmpty ? 'Expense' : _notesController.text.trim(),
        'date': Timestamp.fromDate(fullDateTime),
        'createdAt': FieldValue.serverTimestamp(),
        'billImages': imageUrls,
        'items': _itemsList,
        'itemsTotal': _itemsTotalAmount,
        'isRecurring': _isRecurring,
        'reminderDate': _selectedReminderDate != null 
      ? Timestamp.fromDate(_selectedReminderDate!) 
      : null,
      });

      if (!mounted) return;

      _showSnackBar("Expense added successfully with ${imageUrls.length} bill images!", Colors.green);
      Navigator.pop(context);
      
    } catch (e) {
      _showSnackBar("Error: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

 void _showCalculator() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent, 
    barrierColor: Colors.black.withValues(alpha: 0.5), // Background ko dim karne ke liye
    builder: (context) {
      
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white, // Calculator ka apna background color
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)), // Top rounded corners
        ),
        child: SafeArea(
          top: false, 
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              _CalculatorBottomSheet(
                onResult: (value) {
                  _expenseController.text = value;
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textLight),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Add Expense',
          style: TextStyle(color: textLight, fontWeight: FontWeight.bold),
        ),
        actions: [
           if (_billImages.isNotEmpty) //AppBar mein bills counter 
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expense Input Field
            _buildLabel("Expense", isRequired: true),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _expenseController,
              errorText: _expenseErrorText,
              suffixIcon: IconButton(
                icon: Icon(Icons.calculate, color: saveButtonColor),
                onPressed: _showCalculator,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              prefixText: "Rs. ",
            ),
            const SizedBox(height: 16),

          
            // Category Field
            _buildLabel("Category"),
const SizedBox(height: 8),
Material(
  color: Colors.transparent,
  child: InkWell(
    onTap: _showCategorySelection,
    borderRadius: BorderRadius.circular(8), 
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(_selectedCategoryIcon, color: saveButtonColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedCategory,
              style: TextStyle(
                color: textDark, 
                fontSize: 16,
                fontWeight: _selectedCategory == "Select Category" ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
          Icon(Icons.keyboard_arrow_down, color: saveButtonColor, size: 22),
        ],
      ),
    ),
  ),
),
const SizedBox(height: 16),

            // Payment Method Field
           _buildLabel("Payment Method"),
const SizedBox(height: 8),
Material(
  color: Colors.transparent,
  child: InkWell(
    onTap: _showPaymentMethodSelection,
    borderRadius: BorderRadius.circular(8), 
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: saveButtonColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedPaymentMethod,
              style: TextStyle(
                color: textDark, 
                fontSize: 16,
                fontWeight: _selectedPaymentMethod == "Select Method" ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
          Icon(Icons.keyboard_arrow_down, color: saveButtonColor, size: 22),
        ],
      ),
    ),
  ),
),
const SizedBox(height: 16),
            // Notes Field
            _buildLabel("Notes"),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _notesController,
              hintText: "Write your notes here...", 
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Add Bills & Add Items Buttons Row
            Row(
              children: [
                Expanded(
                  child: _buildOutlineButton(
                    icon: Icons.camera_alt,
                    label: "Add Bills",
                    onTap: _showAddBillsDialog,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOutlineButton(
                    icon: Icons.list_alt,
                    label: "Add Items",
                    onTap: _showItemsDialog,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date and Time Row
            Row(
  children: [
    // Date Picker Box
    Expanded(
      flex: 3,
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.chevron_left, color: saveButtonColor, size: 20),
              Text(
                DateFormat('dd-MMM-yyyy').format(_selectedDate),
                style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Icon(Icons.chevron_right, color: saveButtonColor, size: 20),
              Icon(Icons.calendar_month, color: saveButtonColor, size: 20),
            ],
          ),
        ),
      ),
    ),
    const SizedBox(width: 12),
    // Time Picker Box
    Expanded(
      flex: 2,
      child: InkWell(
        onTap: _selectTime,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedTimeOfDay,
                style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Icon(Icons.access_time, color: saveButtonColor, size: 20),
            ],
          ),
        ),
      ),
    ),
  ],
),
            const SizedBox(height: 20),

/// === Recurring / Set Reminder Field ===
          _buildLabel("Recurring? Set Reminder"),
          const SizedBox(height: 8),
          StatefulBuilder(
            builder: (context, setReminderState) {
              return TextField(
                controller: TextEditingController(text: _reminderText),
                readOnly: true,
                style: TextStyle(color: textDark),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Select reminder date',
                  hintStyle: TextStyle(color: textDark.withValues(alpha: 0.5)),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.calendar_month, color: saveButtonColor, size: 20),
                    onPressed: () async {
                      await _selectReminderDate();
                      setReminderState(() {});
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: saveButtonColor, width: 1.5),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

         // === Bill Images Section ===
          _buildLabel("Bill Images"),
          const SizedBox(height: 8),

          _billImages.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'No bills added',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "Add Bills" to upload',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemCount: _billImages.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade50,
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _billImages[index],
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext dialogContext) {
                                      return AlertDialog(
                                        title: const Text(
                                          'Remove Image?',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                        content: const Text(
                                          'Do you want to remove this bill image?',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(dialogContext).pop(),
                                            child: const Text(
                                              'CANCEL',
                                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(dialogContext).pop();
                                              setState(() {
                                                _billImages.removeAt(index);
                                              });
                                              _showSnackBar('Image removed', Colors.orange);
                                            },
                                            child: const Text(
                                              'REMOVE',
                                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ], // Stack children close
                        ), // Stack close
                      ); // Container close inside itemBuilder
                    }, // itemBuilder close
                  ), // ListView.builder close
                ), // 🌟 Else part Container close (Yeh missing tha!)

          // 🌟 GAP & SAVE BUTTON (Ab yeh bilkul sahi se list array ke andar hain)
          const SizedBox(height: 24), 

          Padding(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
            child: SizedBox(
              width: double.infinity, 
              height: 54, 
              child: ElevatedButton(
                onPressed: _isLoading ? null : _validateAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: saveButtonColor, 
                  foregroundColor: Colors.white,
                  elevation: 2, 
                  shape: const StadiumBorder(), 
                ),
                child: _isLoading 
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        "Save",
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ], // 🌟 Main Column/ListView ke children close
      ), // Column/ListView close
    ), // SingleChildScrollView close
  ); // Scaffold close
} // Build Method close // Build Function close
  // Helper Widget for Labels
  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Text(
      text,
      textAlign: TextAlign.left,
      style: TextStyle(
        color: isRequired ? labelColorRed : textDark,
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
  }

  // Helper Widget for Input Fields
  Widget _buildInputField({
    TextEditingController? controller,
    String? errorText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1, 
    bool autofocus = false, 
    String? prefixText,     
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines, 
      autofocus: autofocus, 
      style: TextStyle(color: textDark),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hoverColor: Colors.white,
        focusColor: Colors.white,
        hintText: hintText,
        hintStyle: TextStyle(color: textDark.withValues(alpha: 0.5)),
        prefixIcon: prefixIcon,
        prefixText: prefixText,
        prefixStyle: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 16),
        suffixIcon: suffixIcon,
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none, 
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: saveButtonColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
    
  }

  // Helper Widget for Outline Buttons
  Widget _buildOutlineButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: saveButtonColor, size: 20),
      label: Text(label, style: TextStyle(color: textDark)),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: textDark.withValues(alpha: 0.15)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
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
    // FIXED: SafeArea aur Padding lagayi hai taake bottom navigation bar ki extra space automatically khatam ho jaye
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16, 
          right: 16, 
          top: 10,
          bottom: MediaQuery.of(context).padding.bottom + 10, // Device screen bottom space control
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Sheet ko fuzool lamba hone se rokega
          children: [
            // Top Handle Indicator
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            
            // Display Area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _expression.isEmpty ? '0' : _expression,
                      style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _result,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF141E27)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Calculator Grid Buttons
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
                    _calcBtn('C', Colors.red.shade50, Colors.red),
                    _calcBtn('0', Colors.grey.shade100, const Color(0xFF141E27)),
                    _calcBtn('.', Colors.grey.shade100, const Color(0xFF141E27)),
                    _calcBtn('+', const Color(0xFFEC407A), Colors.white),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // OK Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC407A),
                  shape: const StadiumBorder(), // Uniform Capsule Shape
                  elevation: 0,
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
      ),
    );
  }
  
  Widget _calcBtn(String text, Color bgColor, Color textColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        // FIXED: Material lagaya taake click color buttons se baahar na bikhre aur extra space na bne
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (text == 'C') {
                _clear();
              } else if (text == '÷') {
                _append('÷'); // Display pr user ko acha sign dikhane ke liye
              } else if (text == '×') {
                _append('×');
              } else {
                _append(text);
              }
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

