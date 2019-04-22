
import os
template = """draft: false
chapter: {chapter}
sutra: {sutra}
position: {position}"""

rank = 1
for root, dirs, files in os.walk("content/"):
	if root != "content/":
		chapter = int(root.replace("content/chapter-","")) 
		
		for f in files:
			if f.endswith(".md"):
				sutra = int(f.replace('sutra-','').replace('.md','')) 
				fp = os.path.join(root, f)
				nmd =""
				with open(fp,'r') as inpf:
					md = inpf.read()
					nmd = md.replace("draft: false",template.format(chapter=chapter,sutra=sutra,position=rank))
					rank = rank + 1
				 
				with open(fp,'w') as inpf:
					inpf.write(nmd)
				print chapter,fp
 