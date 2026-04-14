import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final correoCtrl = TextEditingController();
  final claveCtrl = TextEditingController();
  final repetirCtrl = TextEditingController();
  final nombreCtrl = TextEditingController();

  bool cargando = false;
  bool verClave = false;
  bool verRepetir = false;
  String? error;

  @override
  void dispose() {
    correoCtrl.dispose();
    claveCtrl.dispose();
    repetirCtrl.dispose();
    nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> registrar() async {
    if (nombreCtrl.text.trim().isEmpty ||
        correoCtrl.text.trim().isEmpty ||
        claveCtrl.text.isEmpty ||
        repetirCtrl.text.isEmpty) {
      setState(() => error = 'Completa todos los campos');
      return;
    }

    if (claveCtrl.text != repetirCtrl.text) {
      setState(() => error = 'Las contraseñas no coinciden');
      return;
    }

    if (claveCtrl.text.length < 6) {
      setState(() => error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: correoCtrl.text.trim(),
        password: claveCtrl.text.trim(),
      );

      final user = response.user;
      final session = response.session;

      if (user == null) throw Exception('No se pudo crear el usuario');

      if (session != null) {
        await Supabase.instance.client.from('perfiles').insert({
          'id': user.id,
          'nombre': nombreCtrl.text.trim(),
          'correo': correoCtrl.text.trim(),
          'descripcion': '',
          'foto_perfil': '',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Cuenta creada. Revisa tu correo para verificarla.'),
              ],
            ),
            backgroundColor: Colors.green[700],
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        setState(() => error = 'Error al registrarse: ${e.toString()}');
    }

    if (mounted) setState(() => cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 132,
                  height: 132,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset('logo/logo.png', fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Únete al marketplace',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Crea tu cuenta y empieza a comprar y vender',
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: correoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: claveCtrl,
                obscureText: !verClave,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      verClave ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => verClave = !verClave),
                  ),
                  helperText: 'Mínimo 6 caracteres',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: repetirCtrl,
                obscureText: !verRepetir,
                decoration: InputDecoration(
                  labelText: 'Repetir contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      verRepetir ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => verRepetir = !verRepetir),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => registrar(),
              ),
              const SizedBox(height: 24),

              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              cargando
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : FilledButton(
                      onPressed: registrar,
                      child: const Text('Crear cuenta'),
                    ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿Ya tienes cuenta?',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Inicia sesión'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
