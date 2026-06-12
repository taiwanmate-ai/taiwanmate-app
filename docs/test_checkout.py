import httpx

url = "https://taiwanmate-backend-production.up.railway.app/api/v1/payment/create-checkout"
headers = {"Authorization": "Bearer YOUR_TOKEN", "Content-Type": "application/json"}
r = httpx.post(url, json={"plan": "yearly"}, headers=headers)
print(r.status_code)
print(r.json())
