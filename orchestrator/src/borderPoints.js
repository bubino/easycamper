// Definiamo i punti di passaggio logici tra le diverse mappe (shard).
// La chiave è una combinazione ordinata dei nomi degli shard.
const BORDERS = {
    'europa-centro_europa-sud': [
        { name: 'Brennero (AUT-ITA)', lat: 47.003, lon: 11.506 },
        { name: 'Chiasso (SUI-ITA)', lat: 45.832, lon: 9.031 }
    ],
    'europa-centro_europa-ovest': [
        { name: 'Strasburgo (GER-FRA)', lat: 48.583, lon: 7.750 }
    ],
    'europa-centro_europa-nord': [
        { name: 'Flensburg (GER-DEN)', lat: 54.782, lon: 9.437 }
    ],
    'europa-centro_europa-sud-est': [
        { name: 'Villach (AUT-SLO)', lat: 46.615, lon: 13.848 }
    ],
    'europa-ovest_europa-sud': [
        { name: 'Ventimiglia (FRA-ITA)', lat: 43.791, lon: 7.604 }
    ],
    'europa-sud_europa-sud-est': [
        { name: 'Trieste (ITA-SLO)', lat: 45.650, lon: 13.771 }
    ]
    // Aggiungere altri confini se necessario
};

module.exports = { BORDERS };