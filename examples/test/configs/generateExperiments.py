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
    "ackThresholds": 15,   # if you append these to the name
    "ackDelay": 17         # if you append these to the name
}



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
    experimentKeys = [
        "implementation",
        "congestion",
        "download",
        "rateMbit",
        "delayMs",
        "lossPercent",
        "outageType",
        "maxIdleTimeout",
        "ackThresholds",
        "ackDelays",
    ]

    evaluationKey = [
        "evaluationParams"
    ]

    experiments = []

    experimentValues = [config[experimentKey] for experimentKey in experimentKeys]

    for combination in itertools.product(*experimentValues):
        exp = dict(zip(experimentKeys, combination))

        exp["ackDelay"] = resolve_ack_delay(
            exp.pop("ackDelays"),
            exp["delayMs"]
        )

        exp["name"] = create_name(exp)

        experiments.append(exp)

    sortingBuckets = []

    for parameter, index in PARAMETER_INDICES.items():
        if parameter == "ackDelay":
            bucket = len(config["ackDelays"])
        elif parameter == "ackThresholds":
            bucket = len(config["ackThresholds"])
        else:
            bucket = len(config[parameter])

        sortingBuckets.append({
            "bucket": bucket,
            "indices": [index]
        })
    evaluations = []
  
    evaluationValues = config["evaluationParams"] 
    for e in evaluationValues:
        evaluations.append(e)
   
    

    result = {
        "experiments": experiments,
        "evaluations": [
            {
                "name": "evaluationParams",
                "sortingBucketsAndIndices": sortingBuckets,
                "evaluationDetails": evaluations
            }
        ]
    }
    return result


if __name__ == "__main__":

    with open(sys.argv[1]) as f:
        config = json.load(f)

    result = generateExperiments(config)


    with open(f"../experiments/{sys.argv[1]}", "w") as f:
        json.dump(result, f, indent=4)

    print(f"Generated {len(result['experiments'])} experiments in ../experiments/{sys.argv[1]}")