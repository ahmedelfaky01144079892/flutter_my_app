import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مكيال - لوحة التحكم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepOrange, 
        fontFamily: 'Cairo',
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const AdminHomeScreen(),
    );
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({Key? key}) : super(key: key);

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ClientsListTab(),
    OrdersListTab(),
    ProductsListTab(),
    AddProductTab(),
    AddCategoryTab(),
    AddAnnouncementTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة تطبيق مكيال')),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'العملاء'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'الطلبات'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'المنتجات'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: '+ منتج'),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: '+ قسم'),
          BottomNavigationBarItem(icon: Icon(Icons.announcement), label: '+ رسالة'),
        ],
      ),
    );
  }
}

// ==================== 1. قائمة العملاء والحظر ====================
class ClientsListTab extends StatelessWidget {
  const ClientsListTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text('لا يوجد عملاء حتى الآن'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final user = docs[index].data() as Map<String, dynamic>;
            final isBlocked = user['isBlocked'] ?? false;
            final imageUrl = user['imageUrl'] ?? '';

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                child: imageUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              title: Text(user['name'] ?? 'بدون اسم'),
              subtitle: Text('${user['phone'] ?? 'بدون هاتف'}\n${user['address'] ?? 'بدون عنوان'}'),
              isThreeLine: true,
              trailing: IconButton(
                icon: Icon(isBlocked ? Icons.block : Icons.check_circle, color: isBlocked ? Colors.red : Colors.green),
                onPressed: () {
                  FirebaseFirestore.instance.collection('users').doc(docs[index].id).update({'isBlocked': !isBlocked});
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ==================== 2. قائمة الطلبات وتغيير الحالة ====================
class OrdersListTab extends StatelessWidget {
  const OrdersListTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد طلبات حتى الآن'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final order = docs[index].data() as Map<String, dynamic>;
            final status = order['status'] ?? 'قيد التجهيز';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text('العميل: ${order['userName'] ?? ''} (${order['userPhone'] ?? ''})'),
                subtitle: Text('العنوان: ${order['userAddress'] ?? ''}\nالإجمالي: ${order['totalPrice'] ?? 0} ج.م\nالحالة: $status'),
                isThreeLine: true,
                trailing: DropdownButton<String>(
                  value: ['قيد التجهيز', 'خرج للتوصيل', 'تم التسليم'].contains(status) ? status : 'قيد التجهيز',
                  items: ['قيد التجهيز', 'خرج للتوصيل', 'تم التسليم']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (newStatus) {
                    if (newStatus != null) {
                      FirebaseFirestore.instance.collection('orders').doc(docs[index].id).update({'status': newStatus});
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ==================== 3. قائمة المنتجات وتعديل التوفر ====================
class ProductsListTab extends StatelessWidget {
  const ProductsListTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد منتجات مسجلة'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final product = docs[index].data() as Map<String, dynamic>;
            final isAvailable = product['isAvailable'] ?? true;

            return ListTile(
              title: Text(product['name'] ?? ''),
              subtitle: Text('القسم: ${product['category'] ?? ''} - السعر: ${product['price'] ?? 0} ج.م'),
              trailing: Switch(
                value: isAvailable,
                onChanged: (val) {
                  FirebaseFirestore.instance.collection('products').doc(docs[index].id).update({'isAvailable': val});
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ==================== 4. إضافة منتج جديد ====================
class AddProductTab extends StatefulWidget {
  const AddProductTab({Key? key}) : super(key: key);

  @override
  State<AddProductTab> createState() => _AddProductTabState();
}

class _AddProductTabState extends State<AddProductTab> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedCategory;
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إكمال جميع الحقول واختيار القسم')));
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      String imageUrl = '';
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance.ref().child('products/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('products').add({
        'name': _nameController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'category': _selectedCategory,
        'imageUrl': imageUrl,
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _nameController.clear();
        _priceController.clear();
        _imageFile = null;
        _selectedCategory = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج بنجاح')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: _imageFile != null 
                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_imageFile!, fit: BoxFit.cover)) 
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('اضغط لإضافة صورة المنتج', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم المنتج')),
            TextField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر')),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('categories').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final items = snapshot.data!.docs.map((doc) => doc['name'] as String).toList();

                // التأكد من أن القيمة المحددة موجودة ضمن القائمة الحالية لمنع حدوث Crash
                if (_selectedCategory != null && !items.contains(_selectedCategory)) {
                  _selectedCategory = null;
                }

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'اختر القسم'),
                  value: _selectedCategory,
                  isExpanded: true,
                  items: items.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                );
              },
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: _saveProduct, 
                    child: const Text('إضافة المنتج'),
                  ),
          ],
        ),
      ),
    );
  }
}

// ==================== 5. إضافة قسم جديد ====================
class AddCategoryTab extends StatefulWidget {
  const AddCategoryTab({Key? key}) : super(key: key);

  @override
  State<AddCategoryTab> createState() => _AddCategoryTabState();
}

class _AddCategoryTabState extends State<AddCategoryTab> {
  final _catController = TextEditingController();

  Future<void> _addCategory() async {
    if (_catController.text.isEmpty) return;
    await FirebaseFirestore.instance.collection('categories').add({'name': _catController.text.trim()});
    _catController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة القسم')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(controller: _catController, decoration: const InputDecoration(labelText: 'اسم القسم الجديد')),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _addCategory, 
            child: const Text('إضافة القسم'),
          ),
        ],
      ),
    );
  }
}

// ==================== 6. إضافة رسالة ترحيبية / تحذيرية ====================
class AddAnnouncementTab extends StatefulWidget {
  const AddAnnouncementTab({Key? key}) : super(key: key);

  @override
  State<AddAnnouncementTab> createState() => _AddAnnouncementTabState();
}

class _AddAnnouncementTabState extends State<AddAnnouncementTab> {
  final _msgController = TextEditingController();
  String _type = 'welcome';
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(days: 1));

  Future<void> _saveAnnouncement() async {
    if (_msgController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('announcements').add({
      'message': _msgController.text.trim(),
      'type': _type,
      'startTime': Timestamp.fromDate(_startTime),
      'endTime': Timestamp.fromDate(_endTime),
      'createdAt': FieldValue.serverTimestamp(),
    });

    _msgController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الرسالة بنجاح')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      catchError: (_) {},
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: _msgController, decoration: const InputDecoration(labelText: 'نص الرسالة')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'نوع الرسالة'),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'welcome', child: Text('ترحيبية')),
                DropdownMenuItem(value: 'warning', child: Text('تحذيرية')),
              ],
              onChanged: (val) => setState(() => _type = val!),
            ),
            const SizedBox(height: 10),
            ListTile(
              title: Text('وقت البدء: ${_startTime.toString().substring(0, 16)}'),
              trailing: const Icon(Icons.date_range),
              onTap: () async {
                final date = await showDatePicker(
                  context: context, 
                  initialDate: _startTime, 
                  firstDate: DateTime.now(), 
                  lastDate: DateTime(2030),
                );
                if (date != null && mounted) setState(() => _startTime = date);
              },
            ),
            ListTile(
              title: Text('وقت الانتهاء: ${_endTime.toString().substring(0, 16)}'),
              trailing: const Icon(Icons.date_range),
              onTap: () async {
                final date = await showDatePicker(
                  context: context, 
                  initialDate: _endTime, 
                  firstDate: DateTime.now(), 
                  lastDate: DateTime(2030),
                );
                if (date != null && mounted) setState(() => _endTime = date);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _saveAnnouncement, 
              child: const Text('إرسال / جدولة الرسالة'),
            ),
          ],
        ),
      ),
    );
  }
}
