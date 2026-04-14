import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaChatIA extends StatefulWidget {
  final String? idConversacion;
  const PantallaChatIA({super.key, this.idConversacion});

  @override
  State<PantallaChatIA> createState() => _PantallaChatIAState();
}

class _PantallaChatIAState extends State<PantallaChatIA> {
  final TextEditingController _textoCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<Map<String, String>> _mensajes = [];
  bool _pensando = false;
  String? _idConversacion;
  bool _cargandoHistorial = false;

  static const String _apiKey =
      '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';
  static const String _modelo = 'llama-3.3-70b-versatile';
  static const String _apiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  
  String _contextoProductos = '';

  static const String _promptSistema = '''
Eres un asistente de atención al cliente de un marketplace de compra y venta de productos. 
Tu nombre es "AsistenteIA". Ayudas a los usuarios con preguntas sobre:
- Productos disponibles en la plataforma (nombre, precio, categoría, descripción, ubicación)
- Cómo publicar, buscar o contactar vendedores
- Dudas sobre el uso de la app (chats, perfiles, ubicaciones)
- Información general sobre compras y ventas seguras

Responde siempre en español, de forma amigable, clara y concisa. 
Si el usuario pregunta por un producto específico que ESTÁ en la lista proporcionada abajo, dale detalles (precio, descripción).
Si el usuario pregunta por algo que NO está en la lista, indícale que puede buscarlo en la sección "Inicio" o "Buscar".
Si el usuario quiere contactar a un vendedor, dile que puede hacerlo desde el detalle del producto.
No inventes productos. Usa solo la información proporcionada.
Cuando no sepas algo, sé honesto y sugiere que contacte soporte o explore la app.
''';

  String get _promptCompleto => '''
$_promptSistema

PRODUCTOS DISPONIBLES ACTUALMENTE:
${_contextoProductos.isEmpty ? 'Cargando productos...' : _contextoProductos}
''';

  @override
  void initState() {
    super.initState();
    _idConversacion = widget.idConversacion;
    _cargarProductos();
    
    if (_idConversacion != null) {
      _cargarHistorial();
    } else {
      _iniciarNuevaConversacion();
    }
  }

  Future<void> _cargarHistorial() async {
    setState(() => _cargandoHistorial = true);
    try {
      final res = await Supabase.instance.client
          .from('mensajes_ia')
          .select()
          .eq('id_conversacion', _idConversacion!)
          .order('fecha_envio', ascending: true);

      final List mensajes = res as List;
      
      if (mounted) {
        setState(() {
          _mensajes.clear();
          if (mensajes.isEmpty) {
            _mensajes.add({
              'role': 'assistant',
              'content': '¡Hola de nuevo! 👋 ¿En qué puedo ayudarte?',
            });
          } else {
            for (var m in mensajes) {
              _mensajes.add({
                'role': m['rol'],
                'content': m['contenido'],
              });
            }
          }
          _cargandoHistorial = false;
        });
        _desplazarAlFinal();
      }
    } catch (e) {
      debugPrint('Error cargando historial IA: $e');
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  Future<void> _iniciarNuevaConversacion() async {
    setState(() {
      _mensajes.clear();
      _mensajes.add({
        'role': 'assistant',
        'content': '¡Hola! 👋 Soy tu asistente del marketplace. ¿En qué puedo ayudarte hoy?\n\nPuedo orientarte sobre productos, cómo publicar artículos y más.',
      });
    });

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final res = await Supabase.instance.client
          .from('conversaciones_ia')
          .insert({'id_usuario': uid})
          .select()
          .single();
      if (mounted) setState(() => _idConversacion = res['id']);
    } catch (e) {
      debugPrint('Error al crear conversación IA: $e');
    }
  }

  Future<void> _cargarProductos() async {
    try {
      final data = await Supabase.instance.client
          .from('productos')
          .select('nombre, precio, descripcion, categorias(nombre), ubicaciones(nombre)')
          .eq('disponible', true)
          .order('fecha_creacion', ascending: false)
          .limit(20);

      final List productos = data as List;
      String buffer = '';
      
      for (var p in productos) {
        final cat = p['categorias']?['nombre'] ?? 'Sin categoría';
        final ubi = p['ubicaciones']?['nombre'] ?? 'Ubicación no especificada';
        buffer += "- ${p['nombre']} | Precio: \$${p['precio']} | Cat: $cat | Ubic: $ubi | Desc: ${p['descripcion']}\n";
      }

      if (mounted) {
        setState(() => _contextoProductos = buffer);
      }
    } catch (e) {
      debugPrint('Error cargando productos para IA: $e');
      if (mounted) {
        setState(() => _contextoProductos = 'No se pudieron cargar los productos en este momento.');
      }
    }
  }

  Future<void> _guardarMensaje(String rol, String contenido) async {
    if (_idConversacion == null) return;
    try {
      await Supabase.instance.client.from('mensajes_ia').insert({
        'id_conversacion': _idConversacion,
        'rol': rol,
        'contenido': contenido,
      });
    } catch (e) {
      debugPrint('Error guardando mensaje IA: $e');
    }
  }

  Future<void> _enviar() async {
    final texto = _textoCtrl.text.trim();
    if (texto.isEmpty || _pensando) return;

    _textoCtrl.clear();

    setState(() {
      _mensajes.add({'role': 'user', 'content': texto});
      _pensando = true;
    });

    _desplazarAlFinal();
    await _guardarMensaje('user', texto);

    try {
      final historialApi = _mensajes
          .skip(1)
          .map((m) => {'role': m['role']!, 'content': m['content']!})
          .toList();

      final respuesta = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _modelo,
          'messages': [
            {'role': 'system', 'content': _promptCompleto},
            ...historialApi,
          ],
          'max_tokens': 1024,
          'temperature': 0.7,
        }),
      );

      if (!mounted) return;

      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        final choices = datos['choices'] as List;
        
        if (choices.isNotEmpty) {
          final contenidoRespuesta = choices[0]['message']['content'] as String;

          setState(() {
            _mensajes.add({'role': 'assistant', 'content': contenidoRespuesta});
            _pensando = false;
          });

          await _guardarMensaje('assistant', contenidoRespuesta);
        } else {
          _mostrarError('No recibí una respuesta clara del asistente.');
        }
      } else {
        final errorMsg = jsonDecode(respuesta.body)['error']?['message'] ?? 'Error desconocido';
        debugPrint('Error API Groq (${respuesta.statusCode}): $errorMsg');
        
        if (respuesta.statusCode == 401) {
          _mostrarError('La llave de la API no es válida o ha expirado.');
        } else if (respuesta.statusCode == 429) {
          _mostrarError('Se ha alcanzado el límite de mensajes. Espera un momento.');
        } else {
          _mostrarError();
        }
      }
    } catch (e) {
      debugPrint('Error API Groq: $e');
      if (mounted) _mostrarError();
    }

    _desplazarAlFinal();
  }

  void _mostrarError([String? mensaje]) {
    if (!mounted) return;
    setState(() {
      _mensajes.add({
        'role': 'assistant',
        'content': mensaje ??
            'Lo siento, tuve un problema al procesar tu mensaje. Por favor intenta de nuevo.',
      });
      _pensando = false;
    });
  }

  void _desplazarAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textoCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 360;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: widget.idConversacion != null,
        titleSpacing: widget.idConversacion != null ? 0 : 12,
        actions: [
          if (widget.idConversacion == null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Nueva conversación',
              onPressed: () {
                if (!_pensando) _iniciarNuevaConversacion();
              },
            ),
        ],
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _cargandoHistorial ? 'Cargando...' : 'Asistente IA',
                    style: TextStyle(
                      fontSize: isSmall ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: _cargandoHistorial ? Colors.orange : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        _cargandoHistorial ? 'Sincronizando' : 'En línea',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _cargandoHistorial
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 8 : 12,
                vertical: 12,
              ),
              itemCount: _mensajes.length + (_pensando ? 1 : 0),
              itemBuilder: (context, i) {
                if (_pensando && i == _mensajes.length) {
                  return _BurbujaPensando(colorScheme: colorScheme);
                }
                final msg = _mensajes[i];
                final esUsuario = msg['role'] == 'user';
                return _BurbujaMensaje(
                  contenido: msg['content']!,
                  esUsuario: esUsuario,
                  colorScheme: colorScheme,
                  isSmall: isSmall,
                );
              },
            ),
          ),

          _CampoEntrada(
            controller: _textoCtrl,
            pensando: _pensando,
            onEnviar: _enviar,
            colorScheme: colorScheme,
            isSmall: isSmall,
          ),
        ],
      ),
    );
  }
}

class _BurbujaMensaje extends StatelessWidget {
  final String contenido;
  final bool esUsuario;
  final ColorScheme colorScheme;
  final bool isSmall;

  const _BurbujaMensaje({
    required this.contenido,
    required this.esUsuario,
    required this.colorScheme,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: esUsuario
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esUsuario) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 6, bottom: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.tertiary],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 10 : 13,
                vertical: isSmall ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: esUsuario
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(esUsuario ? 16 : 4),
                  bottomRight: Radius.circular(esUsuario ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                contenido,
                style: TextStyle(
                  color: esUsuario
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                  fontSize: isSmall ? 13 : 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (esUsuario) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _BurbujaPensando extends StatefulWidget {
  final ColorScheme colorScheme;
  const _BurbujaPensando({required this.colorScheme});

  @override
  State<_BurbujaPensando> createState() => _BurbujaPensandoState();
}

class _BurbujaPensandoState extends State<_BurbujaPensando>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 6, bottom: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.colorScheme.primary,
                  widget.colorScheme.tertiary,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i * 0.3;
                    final val = ((_anim.value - delay) % 1.0).clamp(0.0, 1.0);
                    final opacity = (val < 0.5 ? val * 2 : (1 - val) * 2).clamp(
                      0.3,
                      1.0,
                    );
                    return Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: widget.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CampoEntrada extends StatelessWidget {
  final TextEditingController controller;
  final bool pensando;
  final VoidCallback onEnviar;
  final ColorScheme colorScheme;
  final bool isSmall;

  const _CampoEntrada({
    required this.controller,
    required this.pensando,
    required this.onEnviar,
    required this.colorScheme,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(isSmall ? 8 : 12, 8, isSmall ? 8 : 12, 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  enabled: !pensando,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onEnviar(),
                  style: TextStyle(fontSize: isSmall ? 13 : 14),
                  decoration: InputDecoration(
                    hintText: pensando
                        ? 'El asistente está escribiendo...'
                        : 'Escribe tu pregunta...',
                    hintStyle: TextStyle(
                      fontSize: isSmall ? 12 : 13,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmall ? 12 : 16,
                      vertical: 10,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: pensando
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: pensando
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: colorScheme.onPrimary,
                        size: 20,
                      ),
                onPressed: pensando ? null : onEnviar,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
