int n_tags=0;
int beta =1; // Max number of paths to be considered vulnerable (Paramter for vulnerability probability calculation)
int tag_diameter;


class Tag {
  Tree tree;
  Table logs;
  final int id; 
  ArrayList <Tag> onehops; //One hop neighbours
  ArrayList <Tag> twohops; //two hop neighbours
  int neighb_change=0;
  //int[][] routes; // Routes for BN
  ArrayList <IntList> routes; // Routes for BN
  ArrayList <ArrayList<Tag>> routes__; // Routes for BN
  
  boolean connexed=false; // Used when verifying connexity
  boolean retrieved=false; // Used when retrieving data
  // timers
  int newNeighboursTimer = 0;
   
  Tag (Tree tree) {
    this.tree=tree;
    this.id=n_tags;
    n_tags++;
    onehops = new ArrayList<Tag>();
    twohops = new ArrayList<Tag>();
    routes = new ArrayList<IntList>();
    connexed=false;

    logs = new Table();
    logs.addColumn("log_numb");
    logs.addColumn("id");
    
    newNeighboursTimer = int(random(20));
  }
   
  void go () {
    increment();
    if(newNeighboursTimer==0){ // Rarely update connections (will change only if new node has been added)
      getNeighbours(); // Gets one-hops and two-hops
      if(this.neighb_change>0) this.neighb_change--;
    }  
  }
   
  void draw () {
    noStroke();
    fill(0, 255, 200); // Color between 0 (red) and 43 (yellow)
    
    ellipse(tree.pos.x, tree.pos.y, tag_diameter, tag_diameter);
     
    for (Tag tag : onehops) {
      stroke(150);
      line(this.tree.pos.x, this.tree.pos.y, tag.tree.pos.x, tag.tree.pos.y);
    }
    
    textSize(12);
    fill(255.0);
    text("ID: " + this.id, this.tree.pos.x+8, this.tree.pos.y-10);
    //text("1h: " + this.onehops.size(), this.tree.pos.x-28, this.tree.pos.y-20);
    //text("2h: " + this.twohops.size(), this.tree.pos.x-28, this.tree.pos.y-10);
    //text("vp: " + this.vuln_prob, this.tree.pos.x+8, this.tree.pos.y+8);
  }
  
  // Function that merges all linked nodes into the node at redirect_index
  float[] merge(float[] weights, int redirect_index,int emitter_index){
    for(int i=0;i<onehops.size();i++){
      if(i==emitter_index || i==redirect_index) continue;
      if(ALmatch(onehops.get(i),onehops.get(emitter_index).onehops) && weights[i]>0){
        weights[redirect_index]+=weights[i];
        weights[i]=-redirect_index;
        weights=merge(weights,redirect_index,i);
      }
    }
    return weights;
  }
  
  void getNeighbours () {
    ArrayList<Tag> onehops_ = new ArrayList<Tag>();
    for (int i =0; i < tags.size(); i++) {
      Tag tag = tags.get(i);
      if (tag == this) continue;
      if (PVector.dist(tag.tree.pos, this.tree.pos)<commRadius) {
        onehops_.add(tag);
      }
    }
    if (this.onehops.size()!=onehops_.size()){
      neighb_change=5;
      this.onehops = onehops_;
    }
    
    ArrayList<Tag> twohops_ = new ArrayList<Tag>();
    for (int i=0;i< this.onehops.size();i++){
      Tag onehop=this.onehops.get(i);
      for(int j=0;j<onehop.onehops.size();j++){
        Tag tag=onehop.onehops.get(j);
        if (tag==this) continue;
        if(!ALmatch(tag,twohops_) && !ALmatch(tag,this.onehops)){
          twohops_.add(onehop.onehops.get(j)); // My twohopss are my onehopss' onehopss
        }
      }
    }
    if(this.twohops.size()!=twohops_.size()){
      this.twohops = twohops_;
      neighb_change=5;
    }
  }
  
  // Creates new log and spreads it
  void newLog(int log_numb){
    TableRow newRow = this.logs.addRow();
    newRow.setInt("log_numb",log_numb);
    newRow.setInt("id", this.id);
    if(this.logs.getRowCount()>max_memory) max_memory= this.logs.getRowCount(); // Update global max memory (metric)
  }
  
  // "caller" is the tag that called the function
  // "degree" is the depth since the first call. Used to indicate how many communications are needed for data retrieval
  Table extractLogsNetwork(Tag caller, int degree){
    this.retrieved=true;
    Table all_logs = new Table();
    all_logs.addColumn("log_numb");
    all_logs.addColumn("id");
    
    for(TableRow row : this.logs.rows()){ // Exctract your own logs
      numb_comm+=degree; // Add the number of communications needed for retrieval
      all_logs.addRow(row);
    }
    
    // Extract your one-hops' logs (those that you don't have in common with the caller)
    for(int i=0;i<this.onehops.size();i++){
      if(!onehops.get(i).retrieved && (!ALmatch(onehops.get(i), caller.onehops) || caller==this)){
        Table new_table=new Table();
        new_table=onehops.get(i).extractLogsNetwork(this, degree+1); // Flagging yourself as the caller
        for(TableRow row : new_table.rows()){
          if(!containsLog(all_logs,row)) all_logs.addRow(row); // Merge with existing table
        }
      }
    }
    return all_logs;
  }
  
  //Returns the IDs of the connected nodes :
  IntList connex(Tag caller){
    IntList connex_tags = new IntList(0);
    
    // Add the tag itself:
    connex_tags.append(this.id);
    //Flag yourself as already connexed:
    connexed=true;
      
    // Add your one-hops (those that you don't have in common with the caller)
    for(int i=0;i<this.onehops.size();i++){
      if(!this.onehops.get(i).connexed && (!ALmatch(this.onehops.get(i), caller.onehops) || caller==this)){
        IntList new_connex_tags = new IntList();
        new_connex_tags=this.onehops.get(i).connex(this); // Flagging yourself as the caller
        for(int j=0;j< new_connex_tags.size();j++){
          if(!connex_tags.hasValue(new_connex_tags.get(j))) connex_tags.append(new_connex_tags.get(j)); // Merge with existing group
        }
      }
    }
  return connex_tags;
}
  
  // update timer
  void increment () {
    newNeighboursTimer = (newNeighboursTimer + 1) % 20; // The newNeighboursTimer is between 0 and 19
  }
}


// Function that returns if a Tag had already been included in an ArrayList
boolean ALmatch(Tag tag_, ArrayList<Tag> list){
  for(Tag tag : list){
    if (tag_.equals(tag)) return true;
  }
  return false;
}

boolean containsLog(Table table, TableRow tablerow){
  for(int i=0;i<table.getRowCount();i++){
    int log_numb= table.getInt(i,"log_numb");
    if(log_numb==tablerow.getInt("log_numb")) return true;
  }
  return false;
}

boolean containsID(Table table, TableRow tablerow){
  for(int i=0;i<table.getRowCount();i++){
    int log_numb= table.getInt(i,"log_numb");
    if(log_numb==tablerow.getInt("log_numb")) return true;
  }
  return false;
}

//Is approximately equal
boolean approx(float a ,float b){
  float epsilon=0.0001;
  if(abs(a-b)<epsilon) return true;
  return false;
}

boolean contains(int[] arr, int val) {
  for(int i=0; i<arr.length; i++) {
    if(arr[i]==val) return true;
  }
  return false;
}
