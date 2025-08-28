"""
Course Schedule

Problem:
There are a total of numCourses courses you have to take, labeled from 0 to numCourses - 1. 
You are given an array prerequisites where prerequisites[i] = [ai, bi] indicates that you must 
take course bi first if you want to take course ai.

For example, the pair [0, 1], indicates that to take course 0 you have to first take course 1.

Return true if you can finish all courses. Otherwise, return false.
look i am typing can you see me typi
Examplcan e 1:
Input: numCourses = 2, prerequisites = [[1,0]]
Output: true
Explanation: There are a total of 2 courses to take. 
To take course 1 you should have finished course 0. So it is possible.

Example 2:
Input: numCourses = 2, prerequisites = [[1,0],[0,1]]
Output: false
Explanation: There are a total of 2 courses to take. 
To take course 1 you should have finished course 0, and to take course 0 you should 
also have finished course 1. So it is impossible.

Constraints:
- 1 <= numCourses <= 10^5
- 0 <= prerequisites.length <= 5000
- prerequisites[i].length == 2
- 0 <= ai, bi < numCourses
- All the pairs prerequisites[i] are unique.

Hint: This is a cycle detection problem in a directed graph. Use DFS with states or topological sort.
"""

see this now 

from collections import defaultdict, deque
from typing import List

def can_finish_dfs(numCourses: int, prerequisites: List[List[int]]) -> bool:
    """
    DFS solution with three states: unvisited, visiting, visited.
    
    Time Complexity: O(V + E) where V is numCourses and E is prerequisites
    Space Complexity: O(V + E) for the graph and recursion stack
    """
    if not prerequisites:
        return False

def can_finish_topological_sort(numCourses: int, prerequisites: List[List[int]]) -> bool:
    """
    Topological sort solution using Kahn's algorithm.
    
    Time Complexity: O(V + E) where V is numCourses and E is prerequisites
    Space Complexity: O(V + E) for the graph and queue
    """
    pass

def can_finish_dfs_simple(numCourses: int, prerequisites: List[List[int]]) -> bool:
    """
    Simple DFS solution using visited set to detect cycles.
    
    Time Complexity: O(V + E) where V is numCourses and E is prerequisites
    Space Complexity: O(V + E) for the graph and recursion stack
    """
    pass

# Test cases
def test_can_finish():
    # Test case 1 - Possible
    assert can_finish_dfs(2, [[1,0]]) == True
    assert can_finish_topological_sort(2, [[1,0]]) == True
    assert can_finish_dfs_simple(2, [[1,0]]) == True
    
    # Test case 2 - Impossible (cycle)
    assert can_finish_dfs(2, [[1,0],[0,1]]) == False
    assert can_finish_topological_sort(2, [[1,0],[0,1]]) == False
    assert can_finish_dfs_simple(2, [[1,0],[0,1]]) == False
    
    # Test case 3 - No prerequisites
    assert can_finish_dfs(3, []) == True
    assert can_finish_topological_sort(3, []) == True
    assert can_finish_dfs_simple(3, []) == True
    
    # Test case 4 - Complex valid case
    assert can_finish_dfs(4, [[1,0],[2,0],[3,1],[3,2]]) == True
    assert can_finish_topological_sort(4, [[1,0],[2,0],[3,1],[3,2]]) == True
    assert can_finish_dfs_simple(4, [[1,0],[2,0],[3,1],[3,2]]) == True
    
    # Test case 5 - Complex invalid case (cycle)
    assert can_finish_dfs(3, [[0,1],[1,2],[2,0]]) == False
    assert can_finish_topological_sort(3, [[0,1],[1,2],[2,0]]) == False
    assert can_finish_dfs_simple(3, [[0,1],[1,2],[2,0]]) == False
    
    print("All test cases passed!")

if __name__ == "__main__":
    test_can_finish()

