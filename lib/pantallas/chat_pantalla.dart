import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../servicios/servicio_storage.dart';

class PantallaChat extends StatefulWidget {
  final String idConversacion;

  const PantallaChat({super.key, required this.idConversacion});

  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
  final textoCtrl = TextEditingController();
  final scrollCtrl = ScrollController();

  List<dynamic> mensajes = [];
  Map<String, dynamic>? datosConversacion;
  bool cargando = true;
  bool subiendoFoto = false;
  bool grabando = false;
  late RealtimeChannel canal;

  final _audioRecorder = AudioRecorder();

  @override
  void initState() {
    super.initState();
    cargarMensajes();
    escucharMensajes();
    marcarComoLeido();
  }

  void _desplazarAlFinal() {
    if (mounted &&
        scrollCtrl.hasClients &&
        scrollCtrl.position.hasContentDimensions) {
      scrollCtrl.animateTo(
        scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    canal.unsubscribe();
    _audioRecorder.dispose();
    scrollCtrl.dispose();
    textoCtrl.dispose();
    super.dispose();
  }

  Future<void> cargarMensajes() async {
    try {
      final resMensajes = await Supabase.instance.client
          .from('mensajes')
          .select()
          .eq('id_conversacion', widget.idConversacion)
          .order('fecha_envio', ascending: true);

      final resConv = await Supabase.instance.client
          .from('conversaciones')
          .select()
          .eq('id', widget.idConversacion)
          .single();

      setState(() {
        mensajes = resMensajes;
        datosConversacion = resConv;
        cargando = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _desplazarAlFinal());
    } catch (e) {
      debugPrint("ERROR CARGAR MENSAJES: $e");
    }
  }

  void escucharMensajes() {
    canal = Supabase.instance.client
        .channel('chat-${widget.idConversacion}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mensajes',
          callback: (payload) {
            final nuevo = payload.newRecord;

            if (nuevo['id_conversacion'] == widget.idConversacion) {
              if (mounted) {
                setState(() => mensajes.add(nuevo));
              }

              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _desplazarAlFinal(),
              );
              marcarComoLeido();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversaciones',
          callback: (payload) {
            if (mounted && payload.newRecord['id'] == widget.idConversacion) {
              setState(() {
                datosConversacion = {
                  ...?datosConversacion,
                  ...Map<String, dynamic>.from(payload.newRecord),
                };
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> marcarComoLeido() async {
    final uid = Supabase.instance.client.auth.currentUser!.id;

    final conv = await Supabase.instance.client
        .from('conversaciones')
        .select()
        .eq('id', widget.idConversacion)
        .single();

    final esComprador = conv['id_comprador'] == uid;

    await Supabase.instance.client
        .from('conversaciones')
        .update({
          esComprador ? 'comprador_tiene_nuevos' : 'vendedor_tiene_nuevos':
              false,
        })
        .eq('id', widget.idConversacion);
  }

  Future<void> _enviarDatosMensaje(Map<String, dynamic> datos) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;

    try {
      await Supabase.instance.client.from('mensajes').insert({
        'id_conversacion': widget.idConversacion,
        'id_remitente': uid,
        ...datos,
      });

      final conv = await Supabase.instance.client
          .from('conversaciones')
          .select()
          .eq('id', widget.idConversacion)
          .single();

      final esComprador = conv['id_comprador'] == uid;

      await Supabase.instance.client
          .from('conversaciones')
          .update({
            'ultima_actualizacion': DateTime.now().toIso8601String(),
            'comprador_tiene_nuevos': !esComprador,
            'vendedor_tiene_nuevos': esComprador,
          })
          .eq('id', widget.idConversacion);
    } catch (e) {
      debugPrint("ERROR ENVIAR MENSAJE: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al enviar mensaje")),
        );
      }
    }
  }

  Future<void> enviarMensaje() async {
    final texto = textoCtrl.text.trim();
    if (texto.isEmpty) return;

    textoCtrl.clear();
    await _enviarDatosMensaje({'texto': texto});
  }

  Future<void> enviarFoto() async {
    final picker = ImagePicker();
    final archivoSeleccionado = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (archivoSeleccionado == null) return;

    setState(() => subiendoFoto = true);
    final url = await ServicioStorage.subirImagen(
      File(archivoSeleccionado.path),
      'chats',
    );
    setState(() => subiendoFoto = false);

    if (url != null) {
      await _enviarDatosMensaje({'texto': '', 'imagen_url': url});
    }
  }

  Future<void> empezarGrabacion() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => grabando = true);
      }
    } catch (e) {
      debugPrint("ERROR AL GRABAR: $e");
    }
  }

  Future<void> detenerGrabacion() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => grabando = false);

      if (path != null) {
        setState(() => subiendoFoto = true);
        final url = await ServicioStorage.subirImagen(File(path), 'audios');
        setState(() => subiendoFoto = false);

        if (url != null) {
          await _enviarDatosMensaje({'texto': '', 'audio_url': url});
        }
      }
    } catch (e) {
      debugPrint("ERROR AL DETENER GRABACION: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chat")),
      body: Column(
        children: [
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: mensajes.length,
                    itemBuilder: (context, i) {
                      final m = mensajes[i];
                      final soyYo =
                          m['id_remitente'] ==
                          Supabase.instance.client.auth.currentUser!.id;

                      return Align(
                        alignment: soyYo
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: soyYo
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (m['imagen_url'] != null &&
                                  m['imagen_url'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      m['imagen_url'],
                                      width: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.broken_image),
                                    ),
                                  ),
                                ),
                              if (m['audio_url'] != null &&
                                  m['audio_url'].toString().isNotEmpty)
                                BurbujaAudio(url: m['audio_url'], soyYo: soyYo),
                              if (m['texto'] != null &&
                                  m['texto'].toString().isNotEmpty)
                                Text(
                                  m['texto'],
                                  style: TextStyle(
                                    color: soyYo
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatearFechaHora(
                                      m['fecha_envio'] ??
                                          DateTime.now().toIso8601String(),
                                    ),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: soyYo
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  if (soyYo) ...[
                                    const SizedBox(width: 4),
                                    _buildIconoVisto(m),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          SafeArea(
            child: Row(
              children: [
                subiendoFoto
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.photo),
                        onPressed: enviarFoto,
                      ),
                GestureDetector(
                  onLongPressStart: (_) => empezarGrabacion(),
                  onLongPressEnd: (_) => detenerGrabacion(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.mic,
                      color: grabando ? Colors.red : Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: textoCtrl,
                    decoration: const InputDecoration(
                      hintText: "Escribe un mensaje...",
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: enviarMensaje,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFechaHora(String fechaIso) {
    final fecha = DateTime.parse(fechaIso).toLocal();
    final ahora = DateTime.now();

    int hora = fecha.hour;
    final amPm = hora >= 12 ? 'PM' : 'AM';
    if (hora > 12) hora -= 12;
    if (hora == 0) hora = 12;

    final minutos = fecha.minute.toString().padLeft(2, '0');
    final horaFormateada = "$hora:$minutos $amPm";

    final esHoy =
        fecha.day == ahora.day &&
        fecha.month == ahora.month &&
        fecha.year == ahora.year;

    return esHoy
        ? horaFormateada
        : "${fecha.day}/${fecha.month} $horaFormateada";
  }

  Widget _buildIconoVisto(dynamic mensaje) {
    if (datosConversacion == null) return const SizedBox.shrink();

    final uid = Supabase.instance.client.auth.currentUser!.id;
    final esComprador = datosConversacion!['id_comprador'] == uid;

    final visto = esComprador
        ? !datosConversacion!['vendedor_tiene_nuevos']
        : !datosConversacion!['comprador_tiene_nuevos'];

    return Icon(
      visto ? Icons.done_all : Icons.done,
      size: 14,
      color: visto ? Colors.lightBlueAccent : Colors.white60,
    );
  }
}

class BurbujaAudio extends StatefulWidget {
  final String url;
  final bool soyYo;

  const BurbujaAudio({super.key, required this.url, required this.soyYo});

  @override
  State<BurbujaAudio> createState() => _BurbujaAudioState();
}

class _BurbujaAudioState extends State<BurbujaAudio> {
  final audioPlayer = AudioPlayer();
  bool estaTocando = false;
  Duration posicion = Duration.zero;
  Duration duracion = Duration.zero;

  @override
  void initState() {
    super.initState();
    audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => estaTocando = state == PlayerState.playing);
    });
    audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => posicion = p);
    });
    audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => duracion = d);
    });
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorIcono = widget.soyYo
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(estaTocando ? Icons.pause : Icons.play_arrow),
          color: colorIcono,
          onPressed: () {
            if (estaTocando) {
              audioPlayer.pause();
            } else {
              audioPlayer.play(UrlSource(widget.url));
            }
          },
        ),
        Text(
          "${posicion.inMinutes}:${(posicion.inSeconds % 60).toString().padLeft(2, '0')}",
          style: TextStyle(color: colorIcono, fontSize: 12),
        ),
      ],
    );
  }
}
