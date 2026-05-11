import asyncio
from sqlalchemy import text
from app.core.database import engine

async def test():
    async with engine.begin() as conn:
        r = await conn.execute(text("SELECT column_name, data_type FROM information_schema.columns WHERE table_name='trust_portfolios' ORDER BY ordinal_position"))
        for row in r.fetchall():
            print(f"  {row[0]}: {row[1]}")
        print()
        r = await conn.execute(text("SELECT column_name, data_type FROM information_schema.columns WHERE table_name='trust_dividend_history' ORDER BY ordinal_position"))
        print("trust_dividend_history:")
        for row in r.fetchall():
            print(f"  {row[0]}: {row[1]}")

asyncio.run(test())