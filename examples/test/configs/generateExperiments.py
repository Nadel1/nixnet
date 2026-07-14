import json
import itertools
import sys


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
    keys = [
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

    experiments = []

    values = [config[key] for key in keys]

    for combination in itertools.product(*values):
        exp = dict(zip(keys, combination))

        exp["ackDelay"] = resolve_ack_delay(
            exp.pop("ackDelays"),
            exp["delayMs"]
        )

        exp["name"] = create_name(exp)

        experiments.append(exp)

    return {"experiments": experiments}


if __name__ == "__main__":

    with open(sys.argv[1]) as f:
        config = json.load(f)

    result = generateExperiments(config)


    with open(f"../experiments/{sys.argv[1]}", "w") as f:
        json.dump(result, f, indent=4)

    print(f"Generated {len(result['experiments'])} experiments in ../experiments/{sys.argv[1]}")