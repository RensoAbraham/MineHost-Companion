import 'package:flutter/material.dart';
import 'package:dio/dio.dart'; // ¡NUEVO! Importamos Dio

void main() {
  runApp(const MineHostCompanionApp());
}

class MineHostCompanionApp extends StatelessWidget {
  const MineHostCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // --- Estado de la UI ---
  String _serverStatus = "Presiona 'Status' para actualizar";
  bool _isLoading = false;

  // ¡NUEVO! Creamos una instancia de Dio
  // Definimos la URL base de nuestra API de Rust
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));

  // --- Funciones de la API ---

  // ¡NUEVO! 'setState' es la clave de Flutter.
  // Le dice a la UI: "Oye, un dato cambió. ¡Redibújate!"
  // Lo usamos para mostrar el 'loading' y los resultados.

  Future<void> _fetchStatus() async {
    setState(() {
      _isLoading = true;
      _serverStatus = "Actualizando...";
    });

    try {
      // Hacemos la llamada GET a /status
      final response = await _dio.get('/status');
      
      // Parseamos el JSON que nos dio Rust
      final String status = response.data['status'];
      
      setState(() {
        _serverStatus = status; // "running" o "stopped"
        _isLoading = false;
      });
    } catch (e) {
      // Manejo de error si el backend no está corriendo
      setState(() {
        _serverStatus = "Error: ¿Backend está apagado?";
        _isLoading = false;
      });
      print(e); // Imprime el error real en la consola
    }
  }

  Future<void> _startServer() async {
    setState(() {
      _isLoading = true;
      _serverStatus = "Iniciando...";
    });
    
    try {
      // Hacemos la llamada GET a /start
      await _dio.get('/start');
      
      // Le damos 1 segundo al backend para que arranque
      // antes de volver a preguntar el estado
      await Future.delayed(const Duration(seconds: 1));
      
      // Después de iniciar, llamamos a _fetchStatus
      // para confirmar el nuevo estado ("running")
      _fetchStatus(); 
      
    } catch (e) {
      setState(() {
        _serverStatus = "Error al iniciar";
        _isLoading = false;
      });
      print(e);
    }
  }

  Future<void> _stopServer() async {
    setState(() {
      _isLoading = true;
      _serverStatus = "Deteniendo...";
    });
    
    try {
      // Hacemos la llamada GET a /stop
      await _dio.get('/stop');
      
      // Le damos 1 segundo al backend para que se apague
      // antes de volver a preguntar el estado
      await Future.delayed(const Duration(seconds: 1));
      
      // Después de detener, llamamos a _fetchStatus
      // para confirmar el nuevo estado ("stopped")
      _fetchStatus();
      
    } catch (e) {
      setState(() {
        _serverStatus = "Error al detener";
        _isLoading = false;
      });
      print(e);
    }
  }

  // --- UI (la parte visual) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('MineHost Companion - Dashboard'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Estado del Servidor:',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
              ),
              
              // ¡NUEVO! Mostramos un círculo de carga
              // si '_isLoading' es verdadero
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                )
              else
                Text(
                  _serverStatus.toUpperCase(), // ¡NUEVO! En mayúsculas
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              
              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ¡NUEVO! Desactivamos los botones si estamos cargando
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    // Si _isLoading es true, 'onPressed' se pone en 'null',
                    // lo que desactiva el botón automáticamente.
                    onPressed: _isLoading ? null : _startServer,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    onPressed: _isLoading ? null : _stopServer,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),

              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar Status'),
                onPressed: _isLoading ? null : _fetchStatus,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}