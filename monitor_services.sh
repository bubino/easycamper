#!/bin/bash

echo "🌍 Monitoraggio Servizi GraphHopper EasyCamper"
echo "=============================================="

# Funzione per testare un servizio
test_service() {
    local name=$1
    local port=$2
    local url="http://localhost:${port}/info"
    
    if curl -s --connect-timeout 5 "$url" > /dev/null 2>&1; then
        echo "✅ $name (porta $port) - OPERATIVO"
        return 0
    else
        echo "🔄 $name (porta $port) - Processing in corso..."
        return 1
    fi
}

# Loop di monitoraggio
while true; do
    clear
    echo "🌍 Monitoraggio Servizi GraphHopper - $(date)"
    echo "=============================================="
    
    # Test servizi
    nord_ok=false
    centro_ok=false
    sud_ok=false
    
    if test_service "Nord Europa" 8989; then nord_ok=true; fi
    if test_service "Centro Europa" 8990; then centro_ok=true; fi  
    if test_service "Sud Europa" 8991; then sud_ok=true; fi
    
    echo ""
    echo "📊 Utilizzo Risorse:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "(NAME|gh_)"

    echo ""
    echo "📈 Progresso Sud Europa:"  # mostra ultimo log di preprocess per sud
    docker compose logs sud --tail 100 | grep -E "OSMReader: [0-9]+ " | tail -1

    echo ""
    echo "📈 Progresso Centro Europa:"
    docker compose logs centro --tail 100 | grep -E "OSMReader: [0-9]+ " | tail -1

    echo ""
    
    # Check se tutti sono operativi
    if $nord_ok && $centro_ok && $sud_ok; then
        echo "🎉 TUTTI I SERVIZI SONO OPERATIVI!"
        echo ""
        echo "🌐 Test Load Balancer:"
        if curl -s --connect-timeout 5 "http://localhost/info" > /dev/null 2>&1; then
            echo "✅ Nginx Load Balancer - OPERATIVO"
        else
            echo "❌ Nginx Load Balancer - Problema"
        fi
        echo ""
        echo "🚀 Sistema GraphHopper Europa completo e pronto!"
        break
    fi
    
    echo "⏱️  Controllo nuovamente tra 30 secondi..."
    sleep 30
done

echo ""
echo "📝 Test di esempio per ogni regione:"
echo "Nord:   curl 'http://localhost:8989/route?point=51.5074,-0.1278&point=53.4808,-2.2426&vehicle=car'"
echo "Centro: curl 'http://localhost:8990/route?point=52.5200,13.4050&point=48.1351,11.5820&vehicle=car'" 
echo "Sud:    curl 'http://localhost:8991/route?point=41.9028,12.4964&point=40.8518,14.2681&vehicle=car'"
echo "Auto:   curl 'http://localhost/route?point=41.9028,12.4964&point=40.8518,14.2681&vehicle=car'"