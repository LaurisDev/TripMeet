import 'evento_service.dart';

/// Opciones del filtro de fecha en la lista de eventos.
enum RangoFecha {
  hoy('Hoy'),
  estaSemana('Esta semana'),
  esteMes('Este mes'),
  personalizada('Elegir fecha');

  const RangoFecha(this.nombre);

  final String nombre;
}

/// Filtros activos en la pantalla "Eventos". Un campo en `null` significa
/// que ese filtro no se aplica.
class FiltroEventos {
  const FiltroEventos({this.rango, this.fechaPersonalizada, this.lugar});

  final RangoFecha? rango;

  /// Día elegido cuando [rango] es [RangoFecha.personalizada].
  final DateTime? fechaPersonalizada;

  /// Lugar elegido, tal como aparece en los eventos.
  final String? lugar;

  bool get tieneFecha => rango != null;
  bool get tieneLugar => lugar != null;
  bool get activo => tieneFecha || tieneLugar;

  FiltroEventos conFecha(RangoFecha rango, {DateTime? dia}) =>
      FiltroEventos(rango: rango, fechaPersonalizada: dia, lugar: lugar);

  FiltroEventos conLugar(String lugar) => FiltroEventos(
    rango: rango,
    fechaPersonalizada: fechaPersonalizada,
    lugar: lugar,
  );

  FiltroEventos sinFecha() => FiltroEventos(lugar: lugar);

  FiltroEventos sinLugar() =>
      FiltroEventos(rango: rango, fechaPersonalizada: fechaPersonalizada);

  /// Texto del chip de fecha: "Esta semana" o "17/10/2026".
  String? get etiquetaFecha {
    final RangoFecha? r = rango;
    if (r == null) return null;
    final DateTime? dia = fechaPersonalizada;
    if (r == RangoFecha.personalizada && dia != null) {
      return '${dia.day.toString().padLeft(2, '0')}/'
          '${dia.month.toString().padLeft(2, '0')}/${dia.year}';
    }
    return r.nombre;
  }

  /// Eventos que cumplen todos los filtros activos, en el mismo orden.
  /// [ahora] define qué es "hoy", "esta semana" y "este mes".
  List<Evento> aplicar(List<Evento> eventos, DateTime ahora) {
    final ({DateTime desde, DateTime hasta})? intervalo = _intervalo(ahora);
    final String? lugarBuscado = lugar == null ? null : _clave(lugar!);

    return <Evento>[
      for (final Evento evento in eventos)
        if ((intervalo == null ||
                (!evento.fechaHora.isBefore(intervalo.desde) &&
                    evento.fechaHora.isBefore(intervalo.hasta))) &&
            (lugarBuscado == null || _clave(evento.lugar) == lugarBuscado))
          evento,
    ];
  }

  /// Intervalo [desde, hasta) del filtro de fecha; `null` si no hay filtro.
  /// La semana va de lunes a domingo.
  ({DateTime desde, DateTime hasta})? _intervalo(DateTime ahora) {
    final DateTime hoy = DateTime(ahora.year, ahora.month, ahora.day);

    switch (rango) {
      case null:
        return null;
      case RangoFecha.hoy:
        return (desde: hoy, hasta: DateTime(hoy.year, hoy.month, hoy.day + 1));
      case RangoFecha.estaSemana:
        return (
          desde: hoy,
          hasta: DateTime(hoy.year, hoy.month, hoy.day + 8 - hoy.weekday),
        );
      case RangoFecha.esteMes:
        return (desde: hoy, hasta: DateTime(hoy.year, hoy.month + 1));
      case RangoFecha.personalizada:
        final DateTime dia = fechaPersonalizada ?? hoy;
        final DateTime inicio = DateTime(dia.year, dia.month, dia.day);
        return (
          desde: inicio,
          hasta: DateTime(inicio.year, inicio.month, inicio.day + 1),
        );
    }
  }
}

/// Lugares distintos de [eventos], ordenados alfabéticamente. "Medellín" y
/// " medellín " cuentan como el mismo lugar; se muestra el primero que aparece.
List<String> lugaresDeEventos(List<Evento> eventos) {
  final Map<String, String> porClave = <String, String>{};
  for (final Evento evento in eventos) {
    final String lugar = evento.lugar.trim();
    if (lugar.isEmpty) continue;
    porClave.putIfAbsent(_clave(lugar), () => lugar);
  }
  return porClave.values.toList()
    ..sort((String a, String b) => _clave(a).compareTo(_clave(b)));
}

String _clave(String lugar) => lugar.trim().toLowerCase();

/// "1 evento encontrado" / "6 eventos encontrados".
String formatearResultadosEventos(int cantidad) =>
    cantidad == 1 ? '1 evento encontrado' : '$cantidad eventos encontrados';
