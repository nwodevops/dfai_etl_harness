# Registro mensual DFAI. Las tres hojas llegan ya cargadas en H2.
# Sin conexiones: main.py escribe APP.DW_DFAI_*.

RESULTADO = pd.DataFrame(
    [
        {"TABLA": "DW_DFAI_RSDRD", "FILAS": len(RSDRD)},
        {"TABLA": "DW_DFAI_MEDIDAS_CORRECTIVAS", "FILAS": len(MEDIDAS)},
        {"TABLA": "DW_DFAI_MULTAS", "FILAS": len(MULTAS)},
    ]
)
