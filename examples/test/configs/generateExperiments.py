import json
import itertools
import sys


PARAMETER_INDICES = {
    "implementation": 0,
    "congestion": 1,
    "delayMs": 2,
    "rateMbit": 4,
    "download": 6,
    "lossPercent": 8,
    "outageType": 14,
    "ackThreshold": 15,   # if you append these to the name
    "ackDelay": 17         # if you append these to the name
}

NECESSARY_EXPERIMENT_KEYS = [
    "implementation",
    "congestion",
    "download",
    "rateMbit",
    "delayMs",
    "lossPercent",
    "outageType",
    "maxIdleTimeout",
    
]
OPTIONAL_EXPERIMENT_KEYS= [
    "ackThreshold",
    "ackDelay",
]



def resolve_ack_delay(value, delay):
    """Resolve delay expressions into numeric values."""
    if isinstance(value, int):
        return value

    expressions = {
        "delay*2/4": delay * 2 // 4,
        "delay*2/2": delay * 2 // 2,
        "delay*2*3/4": delay * 2 * 3 // 4,
        "delay*2": delay * 2,
        "delay*2*2": delay * 2 * 2,
        "delay*2*4": delay * 2 * 4,
    }

    return expressions.get(value, value)


def create_name(exp):
    return (
        f"{exp['implementation']}-"
        f"{exp['congestion']}_"
        f"{exp['delayMs']}ms-rate_"
        f"{exp['rateMbit']}Mbps-download_"
        f"{exp['download']}-loss_"
        f"{exp['lossPercent']}-outageDuration_0-"
        f"outageAmount_0-outageType_"
        f"{exp['outageType']}-"
        f"{exp['congestion']}"
    )


def generateExperiments(config):


    evaluationKey = [
        "evaluationParams"
    ]

    experiments = []
    missing = [k for k in NECESSARY_EXPERIMENT_KEYS if k not in config]
    if missing:
        raise KeyError(f"Missing required config keys: {missing}")

    # Include optional keys only if present
    experimentKeys = NECESSARY_EXPERIMENT_KEYS + [
        k for k in OPTIONAL_EXPERIMENT_KEYS if k in config
    ]

    experimentValues = [config[k] for k in experimentKeys]


    for combination in itertools.product(*experimentValues):
        exp = dict(zip(experimentKeys, combination))

        exp["ackDelay"] = resolve_ack_delay(
            exp.pop("ackDelay"),
            exp["delayMs"]
        )

        exp["name"] = create_name(exp)

        experiments.append(exp)

    sortingBuckets = []

    for parameter, index in PARAMETER_INDICES.items():
        if parameter == "ackDelay":
            length = len(config["ackDelay"])
        elif parameter == "ackThreshold":
            length = len(config["ackThreshold"])
        else:
            length = len(config[parameter])

        sortingBuckets.append({
            "length": length,
            "index": index
        })
    evaluations = []
    evaluationDetails = []
    evaluationValues = config["evaluationParams"] 
    for e in evaluationValues:
        e["sortingBucketsAndIndices"] = sortingBuckets
        evaluations.append(e)
   
    

    result = {
        "experiments": experiments,
        "evaluations": evaluations,
    }
    return result


if __name__ == "__main__":

    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(f"""
============================================================
Experiment Description Generator
============================================================

Generate experiment descriptions from a single JSON configuration file.

Usage:
    python {sys.argv[0]} <config>.json

Required configuration keys:
    {NECESSARY_EXPERIMENT_KEYS}

Optional configuration keys:
    {OPTIONAL_EXPERIMENT_KEYS}

Notes:
  • The script will fail if any required configuration key is missing.
  • The provided values is used to determine:
      - the order and the sorting parameter index (based on '_' and '-' separation)
      - the length of each parameter
  • Evaluation parameters must also be provided.
    Each evaluation parameter consists of:
      - a name
      - evaluationDetails

The final experiment config will bear the same name as the provided config and be found in ../experiments.
For examples and a description of the evaluation parameters,
please refer to the provided configuration files.

============================================================
""")
        exit(0)
    with open(sys.argv[1]) as f:
        config = json.load(f)

    result = generateExperiments(config)


    with open(f"../experiments/{sys.argv[1]}", "w") as f:
        json.dump(result, f, indent=4)

    print(f"Generated {len(result['experiments'])} experiments in ../experiments/{sys.argv[1]}")