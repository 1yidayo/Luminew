import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sql_conn/sql_conn.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: "SQL Server 測試", home: TestPage());
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  _TestPageState createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  // 狀態文字 讓我們知道發生什麼事
  String status = "尚未連線";

  Future<void> connect(BuildContext ctx) async {
    setState(() {
      status = "連線中...";
    });

    try {
      await SqlConn.connect(
        connectionId: "testDB",
        host: "10.0.2.2",      // 👈 關鍵：模擬器連電腦專用 IP
        port: 1433,             // 👈 剛剛開通的 Port (新版是 int)
        database: "LuminewDB",  // 👈 剛剛在 SSMS 建立的資料庫
        username: "sa",         // 👈 剛剛啟用的帳號
        password: "112233",     // 👈 剛剛設定的密碼 (如果不一樣請自己改)
      );

      setState(() {
        status = "✅ 連線成功！(Connected)";
      });
      debugPrint("Connected!");
    } catch (e) {
      setState(() {
        status = "❌ 連線失敗：\n$e";
      });
      debugPrint(e.toString());
    }
  }

  Future<void> read() async {
    try {
      // 讀取剛剛建立的 Users 表格
      var res = await SqlConn.read("testDB", "SELECT * FROM Users");
      setState(() {
        status = "讀取資料成功：\n$res";
      });
      debugPrint(res.toString());
    } catch (e) {
      setState(() {
        status = "讀取失敗：$e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SQL Server 連線測試'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),

              // --- 這就是你要找的按鈕 ---
              ElevatedButton.icon(
                onPressed: () => connect(context),
                icon: const Icon(Icons.wifi),
                label: const Text("1. 連線 (Connect)"),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => read(),
                icon: const Icon(Icons.read_more),
                label: const Text("2. 讀取資料 (Read)"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}