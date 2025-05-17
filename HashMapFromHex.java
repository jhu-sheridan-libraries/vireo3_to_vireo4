//Adapted from code found on the internet somewhere but I cannot find the original source

//import java.io.InputStream; 
//import java.io.ByteArrayInputStream; 
import java.io.FileInputStream; 
import java.io.IOException; 
import java.io.ObjectInputStream; 
import java.util.HashMap; 
import java.util.Iterator; 
import java.util.Map; 
import java.util.Set;

@SuppressWarnings("unchecked")
public class HashMapFromHex{ 
	public static void main(String[] args) 
	{ 
		String paramOne = args[0];
		HashMap<Integer, String> newHashMap = null; 
		try { 
			FileInputStream fileInput = new FileInputStream("./"+paramOne);
			ObjectInputStream objectInput = new ObjectInputStream(fileInput);
			newHashMap = (HashMap)objectInput.readObject();
			objectInput.close(); 
			fileInput.close(); 
		} catch (IOException obj1) { 
			obj1.printStackTrace(); 
			return; 
		} catch (ClassNotFoundException obj2) { 
			//System.out.println("Class not found"); 
			obj2.printStackTrace(); 
			return; 
		} 

		Set set = newHashMap.entrySet(); 
		Iterator iterator = set.iterator(); 

		String result = "[";
		while (iterator.hasNext()) { 
			Map.Entry entry = (Map.Entry)iterator.next(); 
			//System.out.print("key : " + entry.getKey());
			result += '"'+entry.getValue().toString()+'"';
			if(iterator.hasNext()){
				result += ",";
			}
		} 
		result += "]";
		System.out.println(result);
	} 
} 


