import subprocess
import json
import sys
from datetime import datetime

def run_query(query):
    try:
        result = subprocess.check_output(['team-db', query], stderr=subprocess.STDOUT)
        return json.loads(result)
    except subprocess.CalledProcessError as e:
        print(f"Error executing query: {e.output.decode()}")
        return None
    except json.JSONDecodeError:
        print(f"Error decoding JSON output: {result.decode()}")
        return None

def check_automation_health():
    print(f"--- MindFrame Automation Health Check ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')}) ---")
    
    query = """
    SELECT w.name,
           COUNT(*) FILTER (WHERE l.status = 'failed') AS failures,
           COUNT(*) FILTER (WHERE l.status = 'success') AS successes,
           ROUND(
               COUNT(*) FILTER (WHERE l.status = 'success')::DECIMAL /
               NULLIF(COUNT(*), 0) * 100, 2
           ) AS success_rate
    FROM automation_workflows w
    JOIN automation_execution_logs l ON l.workflow_id = w.id
    WHERE l.started_at >= datetime('now', '-24 hours')
    GROUP BY w.id, w.name
    ORDER BY success_rate ASC;
    """
    
    # Note: Using SQLite datetime function instead of postgres NOW() as team-db uses SQLite locally
    # The deployment plan used postgres syntax, I'll adapt it for SQLite here.
    
    data = run_query(query)
    
    if data is None:
        print("Failed to retrieve health data.")
        return

    if not data:
        print("No automation logs found for the last 24 hours.")
        return

    print(f"{'Workflow Name':<30} | {'Success %':<10} | {'Success':<8} | {'Failures':<8}")
    print("-" * 65)
    
    critical_failures = []
    
    for row in data:
        name = row.get('name', 'Unknown')
        rate = row.get('success_rate', 0)
        successes = row.get('successes', 0)
        failures = row.get('failures', 0)
        
        print(f"{name:<30} | {rate:>9.2f}% | {successes:<8} | {failures:<8}")
        
        if rate < 95:
            critical_failures.append(name)
            
    if critical_failures:
        print("\nCRITICAL: The following workflows have low success rates:")
        for name in critical_failures:
            print(f"  - {name}")
        sys.exit(1)
    else:
        print("\nAll systems normal.")

if __name__ == "__main__":
    check_automation_health()
