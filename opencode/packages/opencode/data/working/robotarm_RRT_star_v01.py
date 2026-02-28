import numpy as np
import matplotlib.pyplot as plt
import math
import os
import time

# --- Parameters ---
L1 = 1.0  # Link 1 length
L2 = 1.0  # Link 2 length
OBSTACLES = [
    (1.0, 1.0, 0.4),
    (-0.5, 1.5, 0.3),
    (0.5, -0.5, 0.3)
] # (x, y, radius)

Q_START = np.array([0.0, 0.0])
Q_GOAL = np.array([np.pi/2, np.pi/4])
GOAL_TOL = 0.1
MAX_ITER = 3000
STEP_SIZE = 0.1
SEARCH_RADIUS = 0.5
GOAL_BIAS = 0.1

OUTPUT_DIR = "data/outputs"
OUTPUT_IMG = os.path.join(OUTPUT_DIR, "robotarm_RRT_star_py_v01_result.png")
OUTPUT_DATA = os.path.join(OUTPUT_DIR, "robotarm_RRT_star_py_v01_data.txt")

# --- Helper Functions ---

def forward_kinematics(q):
    """Returns (xe, ye, x_elbow, y_elbow) given q=[theta1, theta2]"""
    x_elbow = L1 * np.cos(q[0])
    y_elbow = L1 * np.sin(q[0])
    xe = x_elbow + L2 * np.cos(q[0] + q[1])
    ye = y_elbow + L2 * np.sin(q[0] + q[1])
    return xe, ye, x_elbow, y_elbow

def check_line_collision(p1, p2, obstacles):
    """Check if line segment p1-p2 intersects with any circular obstacle"""
    p1 = np.array(p1)
    p2 = np.array(p2)
    v = p2 - p1
    
    for ox, oy, r in obstacles:
        center = np.array([ox, oy])
        w = center - p1
        
        c1 = np.dot(w, v)
        c2 = np.dot(v, v)
        
        if c2 == 0:
            dist = np.linalg.norm(center - p1)
        elif c1 <= 0:
            dist = np.linalg.norm(center - p1)
        elif c2 <= c1:
            dist = np.linalg.norm(center - p2)
        else:
            b = c1 / c2
            pb = p1 + b * v
            dist = np.linalg.norm(center - pb)
            
        if dist <= r:
            return True
    return False

def check_collision(q_start, q_end, obstacles):
    """Check collision for robot arm moving from q_start to q_end"""
    steps = 5
    for s in range(steps + 1):
        alpha = s / steps
        q = q_start * (1 - alpha) + q_end * alpha
        xe, ye, x_elbow, y_elbow = forward_kinematics(q)
        
        # Link 1: (0,0) to (x_elbow, y_elbow)
        if check_line_collision([0, 0], [x_elbow, y_elbow], obstacles):
            return True
        # Link 2: (x_elbow, y_elbow) to (xe, ye)
        if check_line_collision([x_elbow, y_elbow], [xe, ye], obstacles):
            return True
    return False

# --- RRT* Class ---

class Node:
    def __init__(self, coord, parent=None, cost=0.0):
        self.coord = coord
        self.parent = parent
        self.cost = cost

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        
    print(f"Starting RRT* Optimization (Python)...")
    start_time = time.time()
    
    nodes = [Node(Q_START, None, 0.0)]
    
    for i in range(MAX_ITER):
        # 1. Sample
        if np.random.rand() < GOAL_BIAS:
            q_rand = Q_GOAL
        else:
            q_rand = np.random.uniform(-np.pi, np.pi, 2)
            
        # 2. Nearest
        dists = [np.linalg.norm(n.coord - q_rand) for n in nodes]
        nearest_idx = np.argmin(dists)
        nearest_node = nodes[nearest_idx]
        
        # 3. Steer
        direction = q_rand - nearest_node.coord
        dist = np.linalg.norm(direction)
        
        if dist > STEP_SIZE:
            q_new = nearest_node.coord + (direction / dist) * STEP_SIZE
        else:
            q_new = q_rand
            
        # 4. Collision Check
        if not check_collision(nearest_node.coord, q_new, OBSTACLES):
            
            # 5. Choose Parent (Cost Optimization)
            new_cost = nearest_node.cost + np.linalg.norm(q_new - nearest_node.coord)
            best_node = nearest_node
            min_cost = new_cost
            
            # Find neighbors
            neighbor_idxs = [idx for idx, n in enumerate(nodes) if np.linalg.norm(n.coord - q_new) <= SEARCH_RADIUS]
            
            for idx in neighbor_idxs:
                neighbor = nodes[idx]
                cost_via_neighbor = neighbor.cost + np.linalg.norm(q_new - neighbor.coord)
                
                if cost_via_neighbor < min_cost:
                    if not check_collision(neighbor.coord, q_new, OBSTACLES):
                        min_cost = cost_via_neighbor
                        best_node = neighbor
                        
            # Add Node
            new_node = Node(q_new, best_node, min_cost)
            nodes.append(new_node)
            
            # 6. Rewire
            for idx in neighbor_idxs:
                neighbor = nodes[idx]
                cost_via_new = new_node.cost + np.linalg.norm(new_node.coord - neighbor.coord)
                
                if cost_via_new < neighbor.cost:
                    if not check_collision(new_node.coord, neighbor.coord, OBSTACLES):
                        neighbor.parent = new_node
                        neighbor.cost = cost_via_new
                        
        if (i+1) % 500 == 0:
            print(f"Iteration {i+1}/{MAX_ITER}...")

    elapsed_time = time.time() - start_time
    
    # --- Extract Path ---
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
        path = np.array(path[::-1]) # Reverse to start->goal
        success = True
    else:
        print("Failed to reach goal.")
        path = None
        success = False

    # --- Visualization ---
    fig, ax = plt.subplots(1, 2, figsize=(12, 6))
    
    # 1. Workspace
    ax[0].set_title(f"Workspace (Cost: {best_goal_node.cost:.2f})")
    ax[0].set_xlim(-2.5, 2.5)
    ax[0].set_ylim(-2.5, 2.5)
    ax[0].set_aspect('equal')
    ax[0].grid(True)
    
    # Obstacles
    for ox, oy, r in OBSTACLES:
        circle = plt.Circle((ox, oy), r, color='gray')
        ax[0].add_patch(circle)
        
    # Path
    if success:
        for q in path[::max(1, len(path)//10)]: # Sample frames
            xe, ye, x_elbow, y_elbow = forward_kinematics(q)
            ax[0].plot([0, x_elbow, xe], [0, y_elbow, ye], 'b-', alpha=0.2)
            
        # Start & Goal
        xe, ye, x_elbow, y_elbow = forward_kinematics(Q_START)
        ax[0].plot([0, x_elbow, xe], [0, y_elbow, ye], 'g-o', linewidth=2, label='Start')
        xe, ye, x_elbow, y_elbow = forward_kinematics(Q_GOAL)
        ax[0].plot([0, x_elbow, xe], [0, y_elbow, ye], 'r-o', linewidth=2, label='Goal')
        ax[0].legend()
    
    # 2. C-Space
    ax[1].set_title("C-Space (Joint Angles)")
    ax[1].set_xlim(-np.pi, np.pi)
    ax[1].set_ylim(-np.pi, np.pi)
    ax[1].set_aspect('equal')
    ax[1].grid(True)
    ax[1].set_xlabel("Theta 1")
    ax[1].set_ylabel("Theta 2")
    
    # Tree (Sampling)
    # for n in nodes:
    #     if n.parent:
    #         ax[1].plot([n.parent.coord[0], n.coord[0]], [n.parent.coord[1], n.coord[1]], 'k-', alpha=0.1, linewidth=0.5)
            
    if success:
        ax[1].plot(path[:,0], path[:,1], 'r-', linewidth=2)
    
    ax[1].plot(Q_START[0], Q_START[1], 'go')
    ax[1].plot(Q_GOAL[0], Q_GOAL[1], 'ro')
    
    plt.savefig(OUTPUT_IMG)
    print(f"Saved plot to {OUTPUT_IMG}")
    
    # --- Save Data ---
    with open(OUTPUT_DATA, "w") as f:
        f.write(f"Success: {success}\n")
        f.write(f"Cost: {best_goal_node.cost if success else 'inf'}\n")
        f.write(f"Time: {elapsed_time:.4f}\n")
        f.write(f"Iterations: {MAX_ITER}\n")
        f.write(f"Nodes: {len(nodes)}\n")
        if success:
            f.write("Path:\n")
            np.savetxt(f, path)
            
    print(f"Saved data to {OUTPUT_DATA}")

if __name__ == "__main__":
    main()
