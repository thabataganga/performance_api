# API Performance Testing for Self-Sovereign Identity (SSI) Digital Identities

This repository contains the scripts and results of the performance tests conducted as part of the master's project on the use of self-sovereign digital identities supported by blockchain.

## Repository Structure

- **LOCAL/**: Contains tests for the development environment.
- **PRODUCAO/**: Contains tests for the production environment.
- **RESULTADOS/**: Contains the results of the tests.

Each environment has subfolders for the two types of requests:

- **ENVIO/**: Proof sending tests.
- **VERIFICACAO/**: Proof verification tests.

## Running the Tests

To run the tests, follow the steps below:

1. Navigate to the desired environment and request type directory:

   ```sh
   cd {AMBIENTE}/{REQUISICAO}
   ```

   Where `{AMBIENTE}` can be `LOCAL` or `PRODUCAO` and `{REQUISICAO}` can be `ENVIO` or `VERIFICACAO`.

2. Grant execution permission to the `send_request.sh` script:

   ```sh
   chmod +x send_requests.sh
   ```

3. Run the script:
   ```sh
   sudo bash send_requests.sh
   ```

## Script `send_requests.sh` Details

The `send_requests.sh` script is responsible for performing the performance tests, collecting CPU and memory usage data, and sending requests to the API. Here is an overview of its main functionalities:

- **Checking and installing `sysstat`**: The script checks if `mpstat` is available and installs the `sysstat` package if necessary.
- **Collecting baseline data**: Collects CPU and memory usage data for 60 seconds before starting the tests.
- **Sending requests**: Performs sequential and parallel tests, sending requests to the API and recording the response time and HTTP status.
- **Calculating statistics**: Calculates performance statistics such as minimum, average, and maximum time, average CPU, and memory usage.
- **Transposing CSV**: Transposes the performance statistics CSV for easier data analysis.

### Script Functions

- **`get_cpu_mem_usage`**: Gets the CPU (%) and RAM (MB and %) usage.
- **`collect_baseline_data`**: Collects CPU and memory usage data for 60 seconds.
- **`calculate_stats`**: Calculates performance statistics from the collected data.
- **`transpose_csv`**: Transposes a CSV file.
- **`run_sequential_test`**: Performs sequential tests with a specified number of requests.
- **`run_parallel_test`**: Performs parallel tests with a specified number of requests.

### Usage Example

To run a sequential test with 100 requests and a parallel test with 10 requests, you can adjust the script as follows:

```sh
# Collecting baseline data for 60 seconds
collect_baseline_data baseline_60s.csv

# Performing a sequential test with 100 requests
run_sequential_test 100 sequential_100_requests.csv

# Performing a parallel test with 10 requests
run_parallel_test 10 parallel_10_requests.csv

## Results

The generated results will be saved in the RESULTADOS folder in CSV format, with American number formatting (1,000.00).

## Contributions
Contributions are welcome! Feel free to open issues or submit pull requests.

---

*This project was developed as part of the master's thesis at the Federal University of São Paulo (Unifesp).
```
