import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

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
  String _installStatus = ""; // ¡NUEVO! Para mostrar el estado de la instalación
  bool _isLoading = false;

  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));

  // --- Funciones de la API ---

  // ¡NUEVO! Función para instalar el servidor
  Future<void> _installServer() async {
    setState(() {
      _isLoading = true;
      _installStatus = "Instalando Paper 1.20.1...";
    });

    try {
      // Hacemos la llamada GET a /install
      final response = await _dio.get('/install');
      
      if (response.data['message'] == 'install_success') {
        final String hash = response.data['hash'];
        setState(() {
          _installStatus = "¡Instalación exitosa! Hash: ${hash.substring(0, 8)}...";
          _isLoading = false;
        });
      } else {
        setState(() {
          _installStatus = "Error: ${response.data['message']}";
          _isLoading = false;
        });
      }
    } catch (e) {
      // Manejo de error si el backend no está corriendo
      setState(() {
        _installStatus = "Error: ¿Backend está apagado?";
        _isLoading = false;
      });
      print(e); // Imprime el error real en la consola
    }
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _isLoading = true;
      _serverStatus = "Actualizando...";
    });

    try {
      final response = await _dio.get('/status');
      final String status = response.data['status'];
      
      setState(() {
        _serverStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _serverStatus = "Error: ¿Backend está apagado?";
        _isLoading = false;
      });
      print(e);
    }
  }

  Future<void> _startServer() async {
    setState(() {
      _isLoading = true;
      _serverStatus = "Iniciando...";
    });
    
    try {
      await _dio.get('/start');
      await Future.delayed(const Duration(seconds: 1));
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
      await _dio.get('/stop');
      await Future.delayed(const Duration(seconds: 1));
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
    // Usamos 'SingleChildScrollView' para evitar que se desborde
    // si la ventana es muy pequeña
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('MineHost Companion - Dashboard'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                
                // --- Sección de Instalación (¡NUEVA!) ---
                const Text(
                  'Instalación del Servidor',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
                ),
                const SizedBox(height: 10),
                // Mostramos el texto de estado de la instalación
                if (_installStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      _installStatus,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // Botón de Instalar
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Instalar/Actualizar Paper 1.20.1'),
                  onPressed: _isLoading ? null : _installServer,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),

                // --- Divisor ---
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Divider(),
                ),

                // --- Sección de Control (la que ya teníamos) ---
                const Text(
                  'Estado del Servidor:',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
                ),
                
                if (_isLoading && _installStatus.isEmpty) // Solo mostrar si cargamos estado
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  )
                else
                  Text(
                    _serverStatus.toUpperCase(),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
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
      ),
    );
  }
}