import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

enum PinMode { setup, verify, normalLock }

class PinLockScreen extends StatefulWidget {
  final PinMode mode;
  final bool isInitialLaunch;
  const PinLockScreen(
      {super.key, required this.mode, this.isInitialLaunch = false});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  late PinMode
      _currentMode; // Local state to allow switching modes (e.g., to setup after recovery)
  String _inputPin = '';
  String _tempPin = '';
  String _message = '';
  bool _isConfirming = false;
  final int _pinLength = 4;

  // State untuk Setup Pertanyaan Keamanan
  bool _isSettingSecurityQuestion = false;
  String _selectedQuestion = 'Di mana kota kelahiran Anda?';
  final _customQuestionCtrl = TextEditingController();
  final _securityAnswerCtrl = TextEditingController();

  // State untuk Verifikasi Pertanyaan Keamanan (Lupa PIN)
  bool _isVerifyingSecurityQuestion = false;
  String _savedQuestion = '';
  String _savedAnswer = '';
  final _verifyAnswerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode;
    _setInitialMessage();
    if (_currentMode == PinMode.normalLock || _currentMode == PinMode.verify) {
      _loadSavedSecurityQuestion();
    }
  }

  @override
  void dispose() {
    _customQuestionCtrl.dispose();
    _securityAnswerCtrl.dispose();
    _verifyAnswerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSecurityQuestion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedQuestion = prefs.getString('app_pin_question') ??
          'Pertanyaan Pemulihan tidak diatur.';
      _savedAnswer = prefs.getString('app_pin_answer') ?? '';
    });
  }

  void _setInitialMessage() {
    switch (_currentMode) {
      case PinMode.setup:
        _message = 'Buat PIN Keamanan Baru';
        break;
      case PinMode.verify:
        _message = 'Masukkan PIN Saat Ini';
        break;
      case PinMode.normalLock:
        _message = 'Aplikasi Terkunci';
        break;
    }
  }

  Future<void> _handleKeyPress(String value) async {
    if (_inputPin.length >= _pinLength) return;

    setState(() {
      _inputPin += value;
    });

    if (_inputPin.length == _pinLength) {
      await Future.delayed(const Duration(milliseconds: 200));
      _verifyInput();
    }
  }

  void _handleBackspace() {
    if (_inputPin.isEmpty) return;
    setState(() {
      _inputPin = _inputPin.substring(0, _inputPin.length - 1);
    });
  }

  Future<void> _verifyInput() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('app_pin') ?? '';

    switch (_currentMode) {
      case PinMode.setup:
        if (!_isConfirming) {
          setState(() {
            _tempPin = _inputPin;
            _inputPin = '';
            _isConfirming = true;
            _message = 'Konfirmasi PIN Baru Anda';
          });
        } else {
          if (_tempPin == _inputPin) {
            // PIN Cocok! Sekarang minta setup Pertanyaan Keamanan sebelum menyimpan
            setState(() {
              _isSettingSecurityQuestion = true;
              _message = 'Atur Pertanyaan Pemulihan';
            });
          } else {
            setState(() {
              _inputPin = '';
              _tempPin = '';
              _isConfirming = false;
              _message = 'PIN tidak cocok. Silakan buat ulang.';
            });
          }
        }
        break;

      case PinMode.verify:
        if (_inputPin == savedPin) {
          if (mounted) Navigator.pop(context, true);
        } else {
          setState(() {
            _inputPin = '';
            _message = 'PIN salah. Silakan coba lagi.';
          });
        }
        break;

      case PinMode.normalLock:
        if (_inputPin == savedPin) {
          if (mounted) {
            if (widget.isInitialLaunch) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            } else {
              Navigator.pop(context, true);
            }
          }
        } else {
          setState(() {
            _inputPin = '';
            _message = 'PIN salah. Silakan coba lagi.';
          });
        }
        break;
    }
  }

  Future<void> _saveSecurityQuestionAndPin() async {
    final question = _selectedQuestion == 'Pertanyaan Kustom'
        ? _customQuestionCtrl.text.trim()
        : _selectedQuestion;
    final answer = _securityAnswerCtrl.text.trim();

    if (question.isEmpty || answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pertanyaan dan jawaban tidak boleh kosong')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_pin', _tempPin);
    await prefs.setString('app_pin_question', question);
    await prefs.setString('app_pin_answer', answer);
    await prefs.setBool('pin_lock_enabled', true);

    if (mounted) {
      if (widget.isInitialLaunch) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // Mode setup dari halaman profil, kembalikan PIN baru
        Navigator.pop(context, _tempPin);
      }
    }
  }

  void _verifyRecoveryAnswer() {
    final inputAnswer = _verifyAnswerCtrl.text.trim();
    if (inputAnswer.toLowerCase() == _savedAnswer.toLowerCase()) {
      // Jawaban benar! Alihkan ke setup PIN baru secara dinamis
      setState(() {
        _isVerifyingSecurityQuestion = false;
        _isSettingSecurityQuestion = false;
        _isConfirming = false;
        _inputPin = '';
        _tempPin = '';
        _currentMode = PinMode.setup;
        _message = 'Buat PIN Keamanan Baru';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jawaban pemulihan salah. Silakan coba lagi.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentMode != PinMode.normalLock,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F19),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0B0F19),
                Color(0xFF1E293B),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      // Icon gembok keamanan
                      Icon(
                        _isSettingSecurityQuestion
                            ? Icons.help_outline
                            : (_isVerifyingSecurityQuestion
                                ? Icons.lock_open_outlined
                                : Icons.lock_outline),
                        color: const Color(0xFF4CAF50),
                        size: 64,
                      ),
                      const SizedBox(height: 24),

                      // Judul & Pesan
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          _message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // VIEW 1: SETTING PERTANYAAN KEAMANAN (SETUP MODE)
                      if (_isSettingSecurityQuestion) ...[
                        _buildSetupQuestionForm(),
                      ]
                      // VIEW 2: VERIFIKASI JAWABAN (LUPA PIN MODE)
                      else if (_isVerifyingSecurityQuestion) ...[
                        _buildVerifyQuestionForm(),
                      ]
                      // VIEW 3: INPUT PIN BIASA (NUMPAD)
                      else ...[
                        _buildPinNumpad(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSetupQuestionForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          const Text(
            'Pertanyaan ini digunakan untuk menyetel ulang PIN jika Anda lupa.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Pilih Pertanyaan',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30)),
            ),
            initialValue: _selectedQuestion,
            items: [
              'Di mana kota kelahiran Anda?',
              'Apa nama hewan peliharaan pertama Anda?',
              'Siapa nama guru SD favorit Anda?',
              'Apa merek motor/mobil pertama Anda?',
              'Pertanyaan Kustom'
            ].map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
            onChanged: (v) {
              setState(() {
                _selectedQuestion = v!;
              });
            },
          ),
          if (_selectedQuestion == 'Pertanyaan Kustom') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customQuestionCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tulis Pertanyaan Anda',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _securityAnswerCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Jawaban Keamanan',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSecurityQuestionAndPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Simpan PIN & Pemulihan',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyQuestionForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          const Text(
            'Jawab pertanyaan pemulihan berikut untuk mengatur ulang PIN Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pertanyaan Keamanan:',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  _savedQuestion,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _verifyAnswerCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Jawaban Anda',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isVerifyingSecurityQuestion = false;
                      _setInitialMessage();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _verifyRecoveryAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Verifikasi',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPinNumpad() {
    return Column(
      children: [
        // Bulatan indicator PIN
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pinLength, (index) {
            final isActive = index < _inputPin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? const Color(0xFF4CAF50) : Colors.transparent,
                border: Border.all(
                  color: isActive ? const Color(0xFF4CAF50) : Colors.white38,
                  width: 2,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 48),

        // Numpad Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNumButton('1'),
                  _buildNumButton('2'),
                  _buildNumButton('3'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNumButton('4'),
                  _buildNumButton('5'),
                  _buildNumButton('6'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNumButton('7'),
                  _buildNumButton('8'),
                  _buildNumButton('9'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _currentMode != PinMode.normalLock
                      ? InkWell(
                          onTap: () => Navigator.pop(context, false),
                          borderRadius: BorderRadius.circular(40),
                          child: Container(
                            width: 70,
                            height: 70,
                            alignment: Alignment.center,
                            child: const Text(
                              'BATAL',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(width: 70, height: 70),
                  _buildNumButton('0'),
                  InkWell(
                    onTap: _handleBackspace,
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: 70,
                      height: 70,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.backspace_outlined,
                        color: Colors.white70,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Tombol Lupa PIN (hanya muncul saat verifikasi atau lock screen aktif)
        if (_currentMode == PinMode.normalLock ||
            _currentMode == PinMode.verify)
          TextButton(
            onPressed: () {
              setState(() {
                _isVerifyingSecurityQuestion = true;
                _message = 'Pemulihan Kode PIN';
              });
            },
            child: const Text(
              'Lupa PIN?',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNumButton(String value) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleKeyPress(value),
        borderRadius: BorderRadius.circular(40),
        splashColor: const Color(0xFF4CAF50).withOpacity(0.2),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12, width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
