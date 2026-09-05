import sqlite3,sys
p='assets/quran/quran.db'; c=sqlite3.connect(p); a=c.execute('select count(*) from ayahs').fetchone()[0]; s=c.execute('select count(*) from surahs').fetchone()[0]; pages=c.execute('select count(*) from pages').fetchone()[0]; print({'ayahs':a,'surahs':s,'pages':pages}); assert a==6236 and s==114; c.close()
