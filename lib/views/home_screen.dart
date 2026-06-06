import 'package:flutter/material.dart';

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import '../controllers/auth_controller.dart';
import '../controllers/transaction_controller.dart';
import '../models/transaction_model.dart';
import 'add_income_screen.dart';
import 'add_expense_screen.dart';

// ignore_for_file: use_build_context_synchronously


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthController _authController = AuthController();
  final TransactionController _transactionController = TransactionController();
  
  int _selectedIndex = 0;
  int _selectedActionCard = 0;
  double _totalBalance = 0;
  double _totalIncome = 0;
  double _totalExpense = 0;
  bool _isListening = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _voiceText = "Tap to start recording Voice to Transaction";

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _listenToTransactions();
  }
  
  void _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {},
      onError: (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _voiceText = "Error: Please try again";
          });
        }
      },
    );
  }
  
  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      if (mounted) setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _voiceText = result.recognizedWords;
              _isListening = false;
            });
          }
          _processVoiceTransaction(result.recognizedWords);
        },
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 2),
        localeId: 'en_US',
      );
    } else {
      if (mounted) {
        setState(() {
          _voiceText = "Speech not available";
          _isListening = false;
        });
      }
    }
  }
  
  void _processVoiceTransaction(String text) {
    String lowerText = text.toLowerCase();
    
    RegExp amountRegex = RegExp(r'(\d+(?:\.\d+)?)');
    Match? amountMatch = amountRegex.firstMatch(lowerText);
    double? amount = amountMatch != null ? double.tryParse(amountMatch.group(1)!) : null;
    
    if (lowerText.contains('income') || lowerText.contains('received')) {
      if (amount != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddIncomeScreen(preFilledAmount: amount)),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddIncomeScreen()),
        );
      }
    } else if (lowerText.contains('expense') || lowerText.contains('spent') || lowerText.contains('paid')) {
      _showAddExpenseDialog();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please say "income" or "expense" followed by amount'),
            backgroundColor: Color(0xFFEC407A),
          ),
        );
      }
    }
  }
  
  void _listenToTransactions() {
    if (_authController.currentUserId == null) return;
    
    _transactionController.getTransactions(_authController.currentUserId!).listen((transactions) {
      final income = _transactionController.calculateTotalIncome(transactions);
      final expense = _transactionController.calculateTotalExpense(transactions);
      
      if (mounted) {
        setState(() {
          _totalIncome = income;
          _totalExpense = expense;
          _totalBalance = income - expense;
        });
      }
    });
  }

  Future<void> _addTransaction({
    required double amount,
    required String category,
    required String type,
    required String description,
    required DateTime date,
  }) async {
    if (_authController.currentUserId == null) return;
    
    final transaction = TransactionModel(
      userId: _authController.currentUserId!,
      amount: amount,
      category: category,
      type: type,
      description: description.isEmpty ? (type == 'income' ? 'Income' : 'Expense') : description,
      date: date,
      createdAt: DateTime.now(),
    );
    
    await _transactionController.addTransaction(transaction);
  }

  void _showAddExpenseDialog() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController categoryController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Expense'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.calendar_today, size: 20, color: Color(0xFFEC407A)),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setDialogState(() {
                                selectedDate = date;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: 'Rs ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        hintText: 'e.g., Food, Transport, etc.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount != null && amount > 0 && categoryController.text.isNotEmpty) {
                      await _addTransaction(
                        amount: amount,
                        category: categoryController.text,
                        type: 'expense',
                        description: descriptionController.text,
                        date: selectedDate,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expense added successfully!'), backgroundColor: Colors.green),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Please enter valid amount and category')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC407A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffbfcff), 
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: 210,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 150,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF141E27), 
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Smart FinSight',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEC407A), 
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 22),
                                onPressed: () => _showCalendarDialog(),
                              ),
                              IconButton(
                                icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                                onPressed: () => _showMenuDialog(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 20,
                      right: 20,
                      child: Row(
                        children: [
                          _buildActionCard(
                            index: 0,
                            title: 'ADD INCOME',
                            icon: Icons.add,
                            color: const Color(0xFFEC407A),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AddIncomeScreen()),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                           _buildActionCard(
                            index: 1,
                            title: 'ADD Expense',
                            icon: Icons.remove,
                            color: const Color(0xFFEC407A),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          _buildActionCard(
                            index: 2,
                            title: 'TRANSACTIONS',
                            icon: Icons.format_list_bulleted_rounded, 
                            color: const Color(0xFF141E27),
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FA), 
                    borderRadius: BorderRadius.circular(28),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Balance',
                        style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rs ${NumberFormat('#,##,###').format(_totalBalance)}',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF141E27)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('INCOME', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('Rs ${NumberFormat('#,##,###').format(_totalIncome)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF141E27))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('EXPENSE', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('Rs ${NumberFormat('#,##,###').format(_totalExpense)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF141E27))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              Column(
                children: [
                  const Text(
                    'Voice to Transaction',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF141E27)),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _startListening,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: _isListening ? const Color(0xFF288C70) : const Color(0xFFEC407A),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? const Color(0xFF288C70) : const Color(0xFFEC407A)).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(_isListening ? Icons.graphic_eq : Icons.mic, color: Colors.white, size: 32),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _voiceText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF141E27)),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Recent Transactions List - WITHOUT ICONS, WITH GREEN/RED COLORS
              _authController.currentUserId == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _EmptyTransactionBox(),
                    )
                  : StreamBuilder<List<TransactionModel>>(
                      stream: _transactionController.getRecentTransactions(_authController.currentUserId!, 5),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: _EmptyTransactionBox(),
                          );
                        }
                        
                        final transactions = snapshot.data!;
                        
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final t = transactions[index];
                            final isIncome = t.type == 'income';
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.description,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          t.category,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${isIncome ? '+' : '-'} Rs ${t.amount.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isIncome ? Colors.green : Colors.red,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(t.date),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) {
            // Insights page - will implement later
          } else if (index == 2) {
            // Budget page - will implement later
          } else if (index == 3) {
            // Profile/Settings page - will implement later
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFEC407A),
        unselectedItemColor: Colors.grey.shade400,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Insights'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Budget'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required int index,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isSelected = _selectedActionCard == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedActionCard = index);
          onTap();
        },
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEC407A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), 
                blurRadius: 10, 
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : const Color(0xFF141E27), size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCalendarDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select Date'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: SizedBox(
            width: 300,
            height: 350,
            child: CalendarDatePicker(
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              onDateChanged: (date) {
                Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Selected: ${DateFormat('dd/MM/yyyy').format(date)}'),
                      backgroundColor: const Color(0xFFEC407A),
                    ),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _showMenuDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Menu'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person, color: Color(0xFFEC407A)),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications, color: Color(0xFFEC407A)),
                title: const Text('Notifications'),
                onTap: () {
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout'),
                onTap: () async {
                  await _authController.signOut();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyTransactionBox extends StatelessWidget {
  const _EmptyTransactionBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid), 
      ),
      child: const Center(
        child: Text(
          'Add your first transaction to start\ntracking',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );
  }
}