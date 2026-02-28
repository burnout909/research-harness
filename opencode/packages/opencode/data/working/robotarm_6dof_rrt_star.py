import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import time
import os

# --- 1. Simulation Setup & Constants ---

# DH Parameters (Standard PUMA-like 6-DOF)
# [a, alpha, d, theta_offset]
L = np.array([
    [0,      np.pi/2,  0.5,  0],    # Joint 1
    [0.5,    0,        0,    0],    # Joint 2
    [0.1,    np.pi/2,  0,    0],    # Joint 3
    [0,     -np.pi/2,  0.4,  0],    # Joint 4
    [0,      np.pi/2,  0,    0],    # Joint 5
    [0,      0,        0.1,  0]     # Joint 6
])

# Obstacles: [x, y, z, radius]
OBSTACLES = np.array([
    [0.8, 0.5, 0.4, 0.20],   # Obstacle 1 (Moved further)
    [-0.5, 0.5, 0.6, 0.20]   # Obstacle 2 (Moved further)
])

# Joint Limits (rad)
Q_MIN = np.array([-np.pi, -np.pi/2, -np.pi, -np.pi, -np.pi, -np.pi])
Q_MAX = np.array([ np.pi,  np.pi/2,  np.pi,  np.pi,  np.pi,  np.pi])

# Task
Q_START = np.array([0, 0, 0, 0, 0, 0], dtype=float)
Q_GOAL  = np.array([np.pi/2, np.pi/4, -np.pi/4, 0, np.pi/4, 0], dtype=float)

# Optimization Parameters
MAX_ITER = 1500
STEP_SIZE = 0.25
SEARCH_RADIUS = 0.8
GOAL_BIAS = 0.1

class Node:
    def __init__(self, coord):
        self.coord = np.array(coord)
        self.parent = None
        self.cost = 0.0

# --- 2. Helper Functions (Kinematics & Collision) ---

def forward_kinematics_chain(q, L):
    """
    Returns a list of 4x4 transformation matrices for each link.
    """
    T_all = []
    T_curr = np.eye(4)
    
    for i in range(6):
        a, alpha, d, theta_off = L[i]
        theta = q[i] + theta_off
        
        ct, st = np.cos(theta), np.sin(theta)
        ca, sa = np.cos(alpha), np.sin(alpha)
        
        Ti = np.array([
            [ct, -st*ca,  st*sa, a*ct],
            [st,  ct*ca, -ct*sa, a*st],
            [0,   sa,     ca,    d],
            [0,   0,      0,     1]
        ])
        
        T_curr = T_curr @ Ti
        T_all.append(T_curr)
        
    return T_all

def check_collision(q1, q2, L, obstacles, steps=3):
    """
    Checks collision for a path segment between q1 and q2.
    Simplified: Checks if any link end-point is inside an obstacle.
    """
    for s in range(steps + 1):
        alpha = s / steps
        q = q1 * (1 - alpha) + q2 * alpha
        
        T_all = forward_kinematics_chain(q, L)
        
        for obs in obstacles:
            ox, oy, oz, r = obs
            obs_center = np.array([ox, oy, oz])
            
            # Check each link origin/end
            # Add base position (0,0,0) check if needed, but usually fixed.
            # We check the end position of each of the 6 links.
            for T in T_all:
                pos = T[:3, 3]
                if np.linalg.norm(pos - obs_center) < (r + 0.05): # 5cm safety margin
                    return True
    return False

# --- 3. RRT* Algorithm ---

def main():
    np.random.seed(42)
    print("Starting 6-DOF RRT* Optimization (Python Port)...")
    start_time = time.time()
    
    nodes = [Node(Q_START)]
    
    goal_reached_idx = -1
    min_dist_to_goal = float('inf')
    
    for i in range(MAX_ITER):
        # 3.1 Sampling
        if np.random.rand() < GOAL_BIAS:
            q_rand = Q_GOAL
        else:
            q_rand = Q_MIN + (Q_MAX - Q_MIN) * np.random.rand(6)
            
        # 3.2 Nearest Node
        dists = [np.linalg.norm(n.coord - q_rand) for n in nodes]
        nearest_idx = np.argmin(dists)
        q_near = nodes[nearest_idx].coord
        
        # 3.3 Steer
        direction = q_rand - q_near
        dist = np.linalg.norm(direction)
        
        if dist > STEP_SIZE:
            q_new = q_near + (direction / dist) * STEP_SIZE
        else:
            q_new = q_rand
            
        # Joint Limits
        q_new = np.clip(q_new, Q_MIN, Q_MAX)
        
        # 3.4 Collision Check
        if not check_collision(q_new, q_near, L, OBSTACLES):
            
            # 3.5 Choose Parent
            # Cost: Cumulative displacement (energy proxy)
            edge_cost = np.linalg.norm(q_new - q_near)**2
            min_cost = nodes[nearest_idx].cost + edge_cost
            best_parent_idx = nearest_idx
            
            # Find neighbors
            dists_new = [np.linalg.norm(n.coord - q_new) for n in nodes]
            neighbor_idxs = [idx for idx, d in enumerate(dists_new) if d <= SEARCH_RADIUS]
            
            for idx in neighbor_idxs:
                pot_edge_cost = np.linalg.norm(q_new - nodes[idx].coord)**2
                cost_via_neighbor = nodes[idx].cost + pot_edge_cost
                
                if cost_via_neighbor < min_cost:
                    if not check_collision(q_new, nodes[idx].coord, L, OBSTACLES):
                        min_cost = cost_via_neighbor
                        best_parent_idx = idx
            
            # Add Node
            new_node = Node(q_new)
            new_node.parent = nodes[best_parent_idx]
            new_node.cost = min_cost
            nodes.append(new_node)
            new_idx = len(nodes) - 1
            
            # 3.6 Rewire
            for idx in neighbor_idxs:
                pot_edge_cost = np.linalg.norm(nodes[idx].coord - q_new)**2
                cost_via_new = new_node.cost + pot_edge_cost
                
                if cost_via_new < nodes[idx].cost:
                    if not check_collision(q_new, nodes[idx].coord, L, OBSTACLES):
                        nodes[idx].parent = new_node
                        nodes[idx].cost = cost_via_new
            
            # Check Goal
            d_goal = np.linalg.norm(q_new - Q_GOAL)
            if d_goal < STEP_SIZE and d_goal < min_dist_to_goal:
                min_dist_to_goal = d_goal
                goal_reached_idx = new_idx
                # We don't break immediately in RRT* to allow further optimization,
                # but for this demo, if we are very close, we can note it.
                
        if (i+1) % 100 == 0:
            print(f"Iteration {i+1}/{MAX_ITER}, Nodes: {len(nodes)}, Best Dist: {min_dist_to_goal:.4f}")

    # --- 4. Extract Path ---
    if goal_reached_idx != -1:
        print("Path Found!")
        path_nodes = []
        curr = nodes[goal_reached_idx]
        while curr is not None:
            path_nodes.append(curr.coord)
            curr = curr.parent
        path_nodes.reverse() # Start to Goal
        
        # Add exact goal
        path_nodes.append(Q_GOAL)
        path = np.array(path_nodes)
        
        # Save results
        save_results(path, nodes)
        
    else:
        print("Path NOT found within iteration limit.")

def save_results(path, nodes):
    # Ensure output dir
    out_dir = "data/outputs"
    os.makedirs(out_dir, exist_ok=True)
    
    # 1. Visualization
    fig = plt.figure(figsize=(10, 8))
    ax = fig.add_subplot(111, projection='3d')
    ax.set_title("6-DOF Robot Arm Path Optimization (RRT*)")
    ax.set_xlabel("X"); ax.set_ylabel("Y"); ax.set_zlabel("Z")
    
    # Draw Obstacles
    u, v = np.mgrid[0:2*np.pi:20j, 0:np.pi:10j]
    for obs in OBSTACLES:
        x = obs[0] + obs[3] * np.cos(u) * np.sin(v)
        y = obs[1] + obs[3] * np.sin(u) * np.sin(v)
        z = obs[2] + obs[3] * np.cos(v)
        ax.plot_wireframe(x, y, z, color='r', alpha=0.3)
        
    # Draw Start & Goal Configuration (Simplified stick model)
    draw_robot(ax, Q_START, L, 'g', label='Start')
    draw_robot(ax, Q_GOAL, L, 'b', label='Goal')
    
    # Draw Path Trace (End-effector)
    ee_traj = []
    for q in path:
        T_all = forward_kinematics_chain(q, L)
        ee_pos = T_all[-1][:3, 3]
        ee_traj.append(ee_pos)
        
        # Draw intermediate poses sparsely
        if np.random.rand() < 0.1: 
             draw_robot(ax, q, L, 'k', alpha=0.1)
             
    ee_traj = np.array(ee_traj)
    ax.plot(ee_traj[:,0], ee_traj[:,1], ee_traj[:,2], 'b-', linewidth=2, label='EE Trajectory')
    
    ax.legend()
    
    img_path = os.path.join(out_dir, "robotarm_6dof_path_py.png")
    plt.savefig(img_path, dpi=150)
    print(f"Plot saved to {img_path}")
    
    # 2. Save Data (Text format for compatibility)
    txt_path = os.path.join(out_dir, "robotarm_6dof_data_py.txt")
    np.savetxt(txt_path, path, header="Joint Angles (q1..q6) along path")
    print(f"Path data saved to {txt_path}")

def draw_robot(ax, q, L, color, alpha=1.0, label=None):
    T_all = forward_kinematics_chain(q, L)
    
    x = [0]; y = [0]; z = [0]
    for T in T_all:
        pos = T[:3, 3]
        x.append(pos[0])
        y.append(pos[1])
        z.append(pos[2])
        
    ax.plot(x, y, z, '-o', color=color, alpha=alpha, linewidth=2, label=label)

if __name__ == "__main__":
    main()
