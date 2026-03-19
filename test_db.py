import asyncio
import asyncpg

async def main():
    try:
        conn = await asyncpg.connect("postgresql://postgres:postgres@localhost:5432/sfcpc")
        print("Success")
        await conn.close()
    except Exception as e:
        print("Failed:", e)

asyncio.run(main())
