import numpy as np
import matplotlib.pyplot as plt
import math
import os
import time

# --- Parameters (Tuned for better success rate) ---
L1 = 1.0
L2 = 1.0
OBSTACLES = [
    (1.0, 1.0, 0.4),
    (-0.5, 1.5, 0.3),
    (0.5, -0.5, 0.3)
]

Q_START = np.array([0.0, 0.0])
Q_GOAL = np.array([np.pi/2, np.pi/4])
GOAL_TOL = 0.15          # Increased tolerance
MAX_ITER = 5000          # Increased iterations
STEP_SIZE = 0.15         # Increased step size
SEARCH_RADIUS = 0.6
GOAL_BIAS = 0.1

OUTPUT_DIR = "data/outputs"
OUTPUT_IMG = os.path.join(OUTPUT_DIR, "robotarm_RRT_star_py_v02_result.png")
OUTPUT_DATA = os.path.join(OUTPUT_DIR, "robotarm_RRT_star_py_v02_data.txt")

# --- Helper Functions ---

def forward_kinematics(q):
    x_elbow = L1 * np.cos(q[0])
    y_elbow = L1 * np.sin(q[0])
    xe = x_elbow + L2 * np.cos(q[0] + q[1])
    ye = y_elbow + L2 * np.sin(q[0] + q[1])
    return xe, ye, x_elbow, y_elbow

def check_line_collision(p1, p2, obstacles):
    p1 = np.array(p1)
    p2 = np.array(p2)
    v = p2 - p1
    for ox, oy, r in obstacles:
        center = np.array([ox, oy])
        w = center - p1
        c1 = np.dot(w, v)
        c2 = np.dot(v, v)
        if c2 == 0: dist = np.linalg.norm(center - p1)
        elif c1 <= 0: dist = np.linalg.norm(center - p1)
        elif c2 <= c1: dist = np.linalg.norm(center - p2)
        else:
            b = c1 / c2
            pb = p1 + b * v
            dist = np.linalg.norm(center - pb)
        if dist <= r: return True
    return False

def check_collision(q_start, q_end, obstacles):
    steps = 5
    for s in range(steps + 1):
        alpha = s / steps
        q = q_start * (1 - alpha) + q_end * alpha
        xe, ye, x_elbow, y_elbow = forward_kinematics(q)
        if check_line_collision([0, 0], [x_elbow, y_elbow], obstacles): return True
        if check_line_collision([x_elbow, y_elbow], [xe, ye], obstacles): return True
    return False

# --- RRT* Class ---

class Node:
    def __init__(self, coord, parent=None, cost=0.0):
        self.coord = coord
        self.parent = parent
        self.cost = cost

def main():
    if not os.path.exists(OUTPUT_DIR): os.makedirs(OUTPUT_DIR)
        
    print(f"Starting RRT* Optimization (Python v02)...")
    start_time = time.time()
    
    nodes = [Node(Q_START, None, 0.0)]
    
    for i in range(MAX_ITER):
        if np.random.rand() < GOAL_BIAS: q_rand = Q_GOAL
        else: q_rand = np.random.uniform(-np.pi, np.pi, 2)
            
        dists = [np.linalg.norm(n.coord - q_rand) for n in nodes]
        nearest_idx = np.argmin(dists)
        nearest_node = nodes[nearest_idx]
        
        direction = q_rand - nearest_node.coord
        dist = np.linalg.norm(direction)
        
        if dist > STEP_SIZE: q_new = nearest_node.coord + (direction / dist) * STEP_SIZE
        else: q_new = q_rand
            
        if not check_collision(nearest_node.coord, q_new, OBSTACLES):
            new_cost = nearest_node.cost + np.linalg.norm(q_new - nearest_node.coord)
            best_node = nearest_node
            min_cost = new_cost
            
            neighbor_idxs = [idx for idx, n in enumerate(nodes) if np.linalg.norm(n.coord - q_new) <= SEARCH_RADIUS]
            
            for idx in neighbor_idxs:
                neighbor = nodes[idx]
                cost_via_neighbor = neighbor.cost + np.linalg.norm(q_new - neighbor.coord)
                if cost_via_neighbor < min_cost:
                    if not check_collision(neighbor.coord, q_new, OBSTACLES):
                        min_cost = cost_via_neighbor
                        best_node = neighbor
                        
            new_node = Node(q_new, best_node, min_cost)
            nodes.append(new_node)
            
            for idx in neighbor_idxs:
                neighbor = nodes[idx]
                cost_via_new = new_node.cost + np.linalg.norm(new_node.coord - neighbor.coord)
                if cost_via_new < neighbor.cost:
                    if not check_collision(new_node.coord, neighbor.coord, OBSTACLES):
                        neighbor.parent = new_node
                        neighbor.cost = cost_via_new
                        
        if (i+1) % 1000 == 0: print(f"Iteration {i+1}/{MAX_ITER}...")

    elapsed_time = time.time() - start_time
    
    dists_to_goal = [np.linalg.norm(n.coord - Q_GOAL) for n in nodes]
    best_goal_idx = np.argmin(dists_to_goal)
    best_goal_node = nodes[best_goal_idx]
    
    if dists_to_goal[best_goal_idx] <= GOAL_TOL:
        print(f"Goal Reached! Cost: {best_goal_node.cost:.4f}")
        path = []
        curr = best_goal_node
        while curr is not None:
            path.append(curr.coord)
            curr = curr.parent
        path = np.array(path[::-1])
        success = True
    else:
        print("Failed to reach goal.")
        path = None
        success = False

    fig, ax = plt.subplots(1, 2, figsize=(12, 6))
    
    # Workspace
    ax[0].set_title(f"Workspace (Cost: {best_goal_node.cost:.2f})")
    ax[0].set_xlim(-2.5, 2.5)
    ax[0].set_ylim(-2.5, 2.5)
    ax[0].set_aspect('equal')
    ax[0].grid(True)
    for ox, oy, r in OBSTACLES:
        circle = plt.Circle((ox, oy), r, color='gray')
        ax[0].add_patch(circle)
    if success:
        for q in path[::max(1, len(path)//15)]:
            xe, ye, x_elbow, y_elbow = forward_kinematics(q)
            ax[0].plot([0, x_elbow, xe], [0, y_elbow, ye], 'b-', alpha=0.1)
        xe, ye, x_elbow, y_elbow = forward_kinematics(Q_START)
        ax[0].plot([0, x_elbow, xe], [0, y_elbow, ye], 'g-o', linewidth=2, label='Start')
        xe, ye, x_elbow, y_elbow = forward_kinematics(Q_GOAL)
        ax[0].plot([0, x_elbow, xe], [0, y_elbow, ye], 'r-o', linewidth=2, label='Goal')
        ax[0].legend()
    
    # C-Space
    ax[1].set_title("C-Space")
    ax[1].set_xlim(-np.pi, np.pi)
    ax[1].set_ylim(-np.pi, np.pi)
    ax[1].set_aspect('equal')
    ax[1].grid(True)
    if success: ax[1].plot(path[:,0], path[:,1], 'r-', linewidth=2)
    ax[1].plot(Q_START[0], Q_START[1], 'go')
    ax[1].plot(Q_GOAL[0], Q_GOAL[1], 'ro')
    
    plt.savefig(OUTPUT_IMG)
    print(f"Saved plot to {OUTPUT_IMG}")
    
    with open(OUTPUT_DATA, "w") as f:
        f.write(f"Success: {success}\n")
        f.write(f"Cost: {best_goal_node.cost if success else 'inf'}\n")
        f.write(f"Time: {elapsed_time:.4f}\n")
        f.write(f"Nodes: {len(nodes)}\n")

if __name__ == "__main__":
    main()
