import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import os

try:
    import imageio

    HAS_IMAGEIO = True
except ImportError:
    HAS_IMAGEIO = False
    print("Warning: imageio module not found. GIF animation will not be saved.")

# Parameters
MAP_SIZE = [100, 100]
START_POS = np.array([5.0, 5.0])
GOAL_POS = np.array([95.0, 95.0])
STEP_SIZE = 0.5
GOAL_THRESHOLD = 2.0  # Increased for easier convergence in demo
MAX_ITER = 5000
OBS_LIST = [
    (30, 30, 10),
    (70, 70, 15),
    (40, 80, 10),
    (80, 40, 10),
    (50, 50, 15),
]  # (x, y, radius)
OUTPUT_GIF = "data/outputs/RRT_basic_exploring_v01.gif"
OUTPUT_IMG = "data/outputs/RRT_basic_exploring_v01_final.png"


class Node:
    def __init__(self, coord, parent=None):
        self.coord = coord
        self.parent = parent


def get_random_node():
    if np.random.rand() < 0.1:
        return Node(GOAL_POS)
    return Node(np.random.rand(2) * MAP_SIZE)


def get_nearest_node(nodes, random_node):
    dists = [np.linalg.norm(node.coord - random_node.coord) for node in nodes]
    min_idx = np.argmin(dists)
    return nodes[min_idx]


def steer(from_node, to_node, extend_length=float("inf")):
    new_node = Node(np.copy(from_node.coord))
    d = to_node.coord - from_node.coord
    dist = np.linalg.norm(d)

    if dist == 0:
        return from_node

    if extend_length > dist:
        extend_length = dist

    new_node.coord = from_node.coord + (d / dist) * extend_length
    new_node.parent = from_node
    return new_node


def check_collision(node, obstacle_list):
    # Boundary check
    if (
        node.coord[0] < 0
        or node.coord[0] > MAP_SIZE[0]
        or node.coord[1] < 0
        or node.coord[1] > MAP_SIZE[1]
    ):
        return False

    # Obstacle check
    for ox, oy, r in obstacle_list:
        if np.linalg.norm(node.coord - np.array([ox, oy])) <= r:
            return False  # Collision
    return True  # Safe


def main():
    if not os.path.exists("data/outputs"):
        os.makedirs("data/outputs")

    nodes = [Node(START_POS)]
    frames = []

    fig, ax = plt.subplots(figsize=(8, 8))

    # Static Background
    for ox, oy, r in OBS_LIST:
        circle = patches.Circle((ox, oy), r, color="gray")
        ax.add_patch(circle)
    ax.plot(START_POS[0], START_POS[1], "go", markersize=10, label="Start")
    ax.plot(GOAL_POS[0], GOAL_POS[1], "rx", markersize=10, label="Goal")
    ax.set_xlim(0, MAP_SIZE[0])
    ax.set_ylim(0, MAP_SIZE[1])
    ax.grid(True)
    ax.set_title("RRT Exploration")

    path_found = False
    print("Starting RRT simulation...")

    for i in range(MAX_ITER):
        rnd_node = get_random_node()
        nearest_node = get_nearest_node(nodes, rnd_node)
        new_node = steer(nearest_node, rnd_node, STEP_SIZE)

        if check_collision(new_node, OBS_LIST):
            nodes.append(new_node)
            ax.plot(
                [nearest_node.coord[0], new_node.coord[0]],
                [nearest_node.coord[1], new_node.coord[1]],
                "-b",
                linewidth=0.5,
            )

            if np.linalg.norm(new_node.coord - GOAL_POS) <= GOAL_THRESHOLD:
                print(f"Goal reached at iteration {i}")
                path_found = True
                # Traceback
                path_coords = [[GOAL_POS[0], GOAL_POS[1]]]
                curr = new_node
                while curr is not None:
                    path_coords.append(curr.coord)
                    curr = curr.parent
                path_arr = np.array(path_coords)
                ax.plot(path_arr[:, 0], path_arr[:, 1], "-r", linewidth=2, label="Path")
                break

        # Save frame for GIF every 50 iterations
        if i % 100 == 0:
            if i % 500 == 0:
                print(f"Iteration {i}...")
            if HAS_IMAGEIO:
                fig.canvas.draw()
                # Use buffer_rgba instead of tostring_rgb
                buf = fig.canvas.buffer_rgba()
                width, height = fig.canvas.get_width_height()
                image = np.frombuffer(buf, dtype=np.uint8).reshape(height, width, 4)
                frames.append(image[:, :, :3])  # Drop Alpha channel

    # Final frame
    ax.legend()
    fig.savefig(OUTPUT_IMG)

    if HAS_IMAGEIO and len(frames) > 0:
        fig.canvas.draw()
        buf = fig.canvas.buffer_rgba()
        width, height = fig.canvas.get_width_height()
        image = np.frombuffer(buf, dtype=np.uint8).reshape(height, width, 4)
        frames.append(image[:, :, :3])

        print(f"Saving GIF to {OUTPUT_GIF}...")
        imageio.mimsave(OUTPUT_GIF, frames, fps=10)
        print("Done.")
    elif not HAS_IMAGEIO:
        print("Skipped GIF generation (imageio missing). Saved final image only.")


if __name__ == "__main__":
    main()
