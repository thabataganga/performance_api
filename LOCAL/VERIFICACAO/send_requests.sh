#!/bin/bash

# Verifica e instala o sysstat se não estiver disponível
if ! command -v mpstat &> /dev/null
then
    echo "mpstat could not be found, installing sysstat..."
    sudo apt-get update && sudo apt-get install -y sysstat
fi

LC_NUMERIC="en_US.UTF-8"
export LC_NUMERIC

URL="http://localhost:8080/instituicao/633de777228176c275235a90/aries/verify-proof"
BEARER_TOKEN="eyJhbGciOiJSUzM4NCIsInR5cCI6IkpXVCIsImtpZCI6IjEifQ.eyJkYXRhIjp7ImlkIjoiNjMzZGU3NzcyMjgxNzZjMjc1MjM1YTkwIiwiaW5zdGl0dWljYW9JZCI6IjYzM2RlNzc3MjI4MTc2YzI3NTIzNWE5MCJ9LCJhdWQiOiI1MTI3MDYyZS02ZjE5LTQ0MzItOTZmNy01ZWE0ZmU0NWZkNTEiLCJpc3MiOiIiLCJpYXQiOjE3MTU5NTU0MDcsImV4cCI6MTcxODc2MzQwN30.bxm32bZmOc7jsisOX1bsmrY_kMcCTBFLeGwQS5ItwB9ZD_KQwq2OsPGWnn1mJ6rHPnLcjMHV2F2pEv8O1UbHuAcWNE4PwF42aRxoYfhnAdp8XgP0xcsHqjNzIfeZEVIB8hEviqqbzdCXXcnxD2zLtN9rN48yf8Y8qF-4yQRzxJ29icosHSkf4h3AZCd2wtrgd1KQ6kSXdO6fQUQdGthNcoJuBDUdNYyWSSRm-FGRJh_aE24xzVrSmCzCSymRAC4xgz-vk0uVKWpV2CQPTzXHMh0Y7uy9E0YbwuqZ01nUWvQqjHBECLdRFRLQVFZnI-mZoWt0xKiypGINOBl5z87R5A"
BODY='{
    "presentation_exchange_id": "18e245e3-007a-4125-bb86-09714be81efd"
}'

# Função para obter o uso de CPU (%) e memória RAM (MB e %)
get_cpu_mem_usage() {
    local cpu_usage=$(mpstat -P ALL 1 1 | awk '/Average:/ && $2 == "all" {printf "%.1f", 100 - $12}')
    local mem_info=$(free -m | awk '/Mem:/ {printf "%.1f %.1f %.1f", $3, $2, $3/$2 * 100}')
    local mem_used=$(echo $mem_info | cut -d' ' -f1)
    local mem_total=$(echo $mem_info | cut -d' ' -f2)
    local mem_usage=$(echo $mem_info | cut -d' ' -f3)
    printf "%.1f,%.1f,%.1f\n" $cpu_usage $mem_used $mem_usage
}

# Função para coletar amostra de 60s dos dados de CPU e MEM
collect_baseline_data() {
    local csv_file=$1
    local start_time=$(date +%s)

    echo "INICIANDO COLETA DE DADOS BASELINE POR 60 SEGUNDOS"
    echo "Time(s),Delta(s),CPU(%),MEM(MB),MEM(%)" > $csv_file

    for ((i=1; i<=60; i++))
    do
        echo "$i s gravado"
        local current_time=$(date +%s)
        local delta_time=$((current_time - start_time))
        cpu_mem_usage=$(get_cpu_mem_usage)
        echo "$i,${delta_time},${cpu_mem_usage}" >> $csv_file
        sleep 1
    done

    echo "Coleta de dados baseline concluída. Os dados foram salvos em $csv_file."
}

# Função para calcular estatísticas
calculate_stats() {
    local file=$1
    awk -F',' 'NR>1 {
        sum_time += $3; sum_cpu += $4; sum_mem_mb += $5; sum_mem_perc += $6; count += 1
        if(min_time == "" || $3 < min_time) min_time = $3;
        if(max_time == "" || $3 > max_time) max_time = $3;
    } END {
        avg_time = sum_time / count;
        avg_cpu = sum_cpu / count;
        avg_mem_mb = sum_mem_mb / count;
        avg_mem_perc = sum_mem_perc / count;
        printf "%.3f,%.3f,%.3f,%.1f,%.1f,%.1f\n", min_time, avg_time, max_time, avg_cpu, avg_mem_mb, avg_mem_perc
    }' $file
}

# Função para transpor um arquivo CSV
transpose_csv() {
    awk '
    {
        for (i=1; i<=NF; i++)  {
            a[NR,i] = $i
        }
    }
    NF>p { p = NF }
    END {
        for(j=1; j<=p; j++) {
            str=a[1,j]
            for(i=2; i<=NR; i++){
                str=str","a[i,j];
            }
            print str
        }
    }' FS=, OFS=, $1
}

# Função para realizar testes sequenciais
run_sequential_test() {
    local num_requests=$1
    local csv_file=$2
    local start_time=$(date +%s)

    echo "INICIANDO TESTE SEQUENCIAL COM $num_requests REQUISIÇÕES"
    echo "Request,Time(s),Delta(s),HTTP Status,CPU(%),MEM(MB),MEM(%)" > $csv_file

    # Loop para enviar requisições sequenciais
    for ((i=1; i<=num_requests; i++))
    do
        echo "Enviando requisição $i..."
        # Enviando a requisição POST e salvando o tempo de resposta e status HTTP
        response=$(curl -o /dev/null -s -w "%{http_code},%{time_total}" -X POST -H "Authorization: Bearer $BEARER_TOKEN" -H "Content-Type: application/json" -d "$BODY" "$URL")
        http_code=$(echo $response | cut -d',' -f1)
        time_total=$(echo $response | cut -d',' -f2)

        local current_time=$(date +%s)
        local delta_time=$((current_time - start_time))
        
        # Obtendo o uso de CPU e memória RAM do sistema
        cpu_mem_usage=$(get_cpu_mem_usage)
        
        echo "$i,${time_total},${delta_time},${http_code},${cpu_mem_usage}" >> $csv_file
    done

    echo "Envio de requisições sequenciais concluído. As estatísticas foram salvas em $csv_file."
}

# Função para realizar testes paralelos
run_parallel_test() {
    local num_requests=$1
    local csv_file=$2
    local start_time=$(date +%s)

    echo "INICIANDO TESTE PARALELO COM $num_requests REQUISIÇÕES"
    echo "Request,Time(s),Delta(s),HTTP Status,CPU(%),MEM(MB),MEM(%)" > $csv_file

    # Loop para enviar requisições em paralelo
    for ((i=1; i<=num_requests; i++))
    do
        (
            echo "Enviando requisição $i..."
            # Enviando a requisição POST e salvando o tempo de resposta e status HTTP
            response=$(curl -o /dev/null -s -w "%{http_code},%{time_total}" -X POST -H "Authorization: Bearer $BEARER_TOKEN" -H "Content-Type: application/json" -d "$BODY" "$URL")
            http_code=$(echo $response | cut -d',' -f1)
            time_total=$(echo $response | cut -d',' -f2)

            local current_time=$(date +%s)
            local delta_time=$((current_time - start_time))
            
            # Obtendo o uso de CPU e memória RAM do sistema
            cpu_mem_usage=$(get_cpu_mem_usage)
            
            echo "$i,${time_total},${delta_time},${http_code},${cpu_mem_usage}" >> $csv_file
        ) &
    done

    # Esperando todas as requisições terminarem
    wait

    echo "Envio de requisições em paralelo concluído. As estatísticas foram salvas em $csv_file."
}

# Coletando dados baseline por 60 segundos
collect_baseline_data baseline_60s.csv

# Realizando teste sequencial com 100 requisições
run_sequential_test 100 sequential_100_requests.csv

# Realizando testes paralelos com 3, 5, 10, 50 e 100 requisições
run_parallel_test 3 parallel_3_requests.csv
run_parallel_test 5 parallel_5_requests.csv
run_parallel_test 10 parallel_10_requests.csv
run_parallel_test 50 parallel_50_requests.csv
run_parallel_test 100 parallel_100_requests.csv

# Cabeçalho do CSV de estatísticas de performance
echo "Teste,Tempo Mínimo(s),Tempo Médio(s),Tempo Máximo(s),CPU Média(%),MEM Média(MB),MEM Média(%)" > performance_stats.csv

# Calculando estatísticas para os dados baseline
baseline_stats=$(calculate_stats baseline_60s.csv)
echo "Baseline,${baseline_stats}" >> performance_stats.csv

# Calculando estatísticas para os testes sequenciais
sequential_stats_100=$(calculate_stats sequential_100_requests.csv)
echo "Sequencial_100,${sequential_stats_100}" >> performance_stats.csv

# Calculando estatísticas para os testes paralelos
parallel_stats_3=$(calculate_stats parallel_3_requests.csv)
echo "Paralelo_3,${parallel_stats_3}" >> performance_stats.csv

parallel_stats_5=$(calculate_stats parallel_5_requests.csv)
echo "Paralelo_5,${parallel_stats_5}" >> performance_stats.csv

parallel_stats_10=$(calculate_stats parallel_10_requests.csv)
echo "Paralelo_10,${parallel_stats_10}" >> performance_stats.csv

parallel_stats_50=$(calculate_stats parallel_50_requests.csv)
echo "Paralelo_50,${parallel_stats_50}" >> performance_stats.csv

parallel_stats_100=$(calculate_stats parallel_100_requests.csv)
echo "Paralelo_100,${parallel_stats_100}" >> performance_stats.csv

echo "Estatísticas de performance salvas em performance_stats.csv."

# Transpor o CSV de estatísticas de performance
transpose_csv performance_stats.csv > transposed_performance_stats.csv

echo "CSV transposto salvo em transposed_performance_stats.csv."
