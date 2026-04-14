import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'navegacion_pantalla.dart';
import 'registro_pantalla.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin>
    with SingleTickerProviderStateMixin {
  final correoCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool cargando = false;
  bool verPass = false;
  String? error;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    correoCtrl.dispose();
    passCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> iniciarSesion() async {
    final correo = correoCtrl.text.trim();
    final pass = passCtrl.text.trim();

    if (correo.isEmpty || pass.isEmpty) {
      setState(() => error = 'Completa todos los campos');
      return;
    }

    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: correo,
        password: pass,
      );

      final user = response.user;
      if (user == null) {
        setState(() => error = 'Credenciales incorrectas');
        setState(() => cargando = false);
        return;
      }

      await _ensurePerfilExists(user.id, user.email ?? correo);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PantallaNavegacion()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message.contains('Invalid login')
              ? 'Correo o contraseña incorrectos'
              : 'Error: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted)
        setState(
          () => error = 'Error al iniciar sesión. Verifica tu conexión.',
        );
    }

    if (mounted) setState(() => cargando = false);
  }

  Future<void> _ensurePerfilExists(String uid, String correo) async {
    try {
      final perfilExistente = await Supabase.instance.client
          .from('perfiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (perfilExistente == null) {
        await Supabase.instance.client.from('perfiles').insert({
          'id': uid,
          'nombre': correo.split('@').first,
          'correo': correo,
          'descripcion': '',
          'foto_perfil': '',
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -size.height * 0.15,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.05,
            left: -size.width * 0.15,
            child: Container(
              width: size.width * 0.5,
              height: size.width * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.secondaryContainer.withValues(alpha: 0.25),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      SizedBox(height: size.height * 0.08),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(
                                alpha: 0.16,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'logo/logo.png',
                            width: 108,
                            height: 108,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Bienvenido',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Encuentra lo que buscas cerca de ti',
                        style: TextStyle(
                          fontSize: 15,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 40),
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
                        controller: passCtrl,
                        obscureText: !verPass,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              verPass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(() => verPass = !verPass),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => iniciarSesion(),
                      ),
                      const SizedBox(height: 24),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: error != null
                            ? Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: colorScheme.onErrorContainer,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            error!,
                                            style: TextStyle(
                                              color:
                                                  colorScheme.onErrorContainer,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      cargando
                          ? Container(
                              height: 52,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(),
                            )
                          : FilledButton(
                              onPressed: iniciarSesion,
                              child: const Text('Iniciar sesión'),
                            ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '¿No tienes cuenta?',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PantallaRegistro(),
                                ),
                              );
                            },
                            child: const Text('Crear cuenta'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
