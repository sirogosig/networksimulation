int n_tags=0;
int beta =1; // Max number of paths to be considered vulnerable (Paramter for vulnerability probability calculation)

class Tag {
  Tree tree;
  Table logs;
  int id; 
  float entropy=0.5;
  float vuln_prob=0.5;
  //PVector suggested_new_cam;
  ArrayList <Tag> onehops; //One hop neighbours
  ArrayList <Tag> twohops; //two hop neighbours
  ArrayList <Tag> bottlenecks; // Onehops that are bottleneck nodes
  ArrayList <Tag> most_vuln; // List of most vulnerable one-hops
  
  // timers
  int newNeighboursTimer = 0;
   
  Tag (Tree tree) {
    this.tree=tree;
    this.id=n_tags;
    n_tags++;
    onehops = new ArrayList<Tag>();
    twohops = new ArrayList<Tag>();
    //suggested_new_cam= new PVector(0,0);
    entropy=0.5;
    
    logs = new Table();
    logs.addColumn("log_numb");
    logs.addColumn("id");
    //logs.addColumn("species");
    //logs.addColumn("day");
    //logs.addColumn("hour");
    //logs.addColumn("minute");
    
    newNeighboursTimer = int(random(20));
  }
   
  void go () {
    increment();
    if(newNeighboursTimer==0){ // Rarely update connections (will change only if new node has been added)
      getNeighbours(); // Gets one-hops and two-hops
      calcVulnProb(); // Computes vp and entropy
      getBottlenecks();
      getMostVulnNeighb(); // Finds the least vulnerable onehops
    }
    //if(communicate){
    //  //Send your data if you are vulnerable
    //  if(this.logs.getRowCount()!=0){
    //  int prob_vp = (int)random(101);
    //    if(prob_vp<this.vuln_prob) {
    //      for(Tag tag : this.onehops){
    //        int prob_entr = (int)random(101);
    //        if(prob_entr>tag.vuln_prob){ // Send a random log to onehops depending on their vp
    //          int random_log=(int)random(this.logs.getRowCount());
    //          int log_numb=this.logs.getInt(random_log, "log_numb");
    //          int id      =this.logs.getInt(random_log, "id");
    //          tag.addLog(log_numb, id);
    //        }
    //      }
    //    }
    //  }
      
    //  //Acquire data if you are a threshold node
      
    //}
  }
   
  void draw () {
    noStroke();
    fill((int)((1-vuln_prob)*43), 255, 200); // Color between 0 (red) and 43 (yellow)
    
    ellipse(tree.pos.x, tree.pos.y, tag_diameter*(0.7+2*entropy), tag_diameter*(0.7+2*entropy));
     
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
  
  void calcVulnProb(){
    ArrayList <Tag> pathbeta= new ArrayList<Tag>();
    for(int i=0;i<twohops.size();i++){
      int numbpaths=0;
      for (int j=0;j<onehops.size();j++){
        if(ALmatch(twohops.get(i), onehops.get(j).onehops)) numbpaths++;
      }
      if(numbpaths==0) print("Error in numbpaths calculation");
      if(numbpaths<=beta && numbpaths>0) pathbeta.add(twohops.get(i));
    }
    if(this.onehops.size() == 0){
      vuln_prob =1;
      entropy=1;
    }
    else{
      this.vuln_prob=((float)pathbeta.size()/((float)(this.onehops.size()+this.twohops.size())));
      this.entropy=calc_entropy(); //Another way of computing the entropy      
    }
    calc_snc(pathbeta);
  }
  
  void calc_snc(ArrayList<Tag> pathbeta){
    if(pathbeta.size()!=0){
      PVector final_pos=new PVector(0,0);      
      for(Tag tag : pathbeta){
        final_pos=PVector.add(final_pos,tag.tree.pos);
      }
      final_pos=PVector.div(final_pos, pathbeta.size()); // Barycenter of all 2-hops with max beta shortest path(s)
      // suggested_new_cam = i + (f-i)/2 : 
      //suggested_new_cam= PVector.add(this.tree.pos, PVector.div(PVector.sub(final_pos,this.tree.pos),2));
    }
  }
  
  // The following calculates the entropy only with unique twohops
  float calc_entropy(){
    float[] total_unique_twohops=new float[this.onehops.size()];
    for(int i=0;i<total_unique_twohops.length;i++) total_unique_twohops[i]=1.0; //initialise at 1 (themselves)
    
    //Share two-hops between one-hops
    for (int i=0;i< this.twohops.size();i++){
      Tag twohop=this.twohops.get(i);
      int links=0;
      for(int j=0;j<onehops.size();j++){
        Tag onehop=onehops.get(j);
        if(ALmatch(twohop,onehop.onehops)){
          links++;
        }
      }
      for(int j=0;j<onehops.size();j++){
        Tag onehop=onehops.get(j);
        if(ALmatch(twohop,onehop.onehops)){
          total_unique_twohops[j]+=1.0/links;
        }
      }
    }

    // Merge connected one-hops
    for(int i=0;i<this.onehops.size();i++){
      if(total_unique_twohops[i]>=1) total_unique_twohops=merge(total_unique_twohops,i,i);
    }
    
    int total=this.twohops.size()+this.onehops.size();
    float entropy=0.0;
    for (int i=0; i<total_unique_twohops.length;i++){
      if(total_unique_twohops[i]>0){
        entropy+=((float)total_unique_twohops[i])/total*log(((float)total_unique_twohops[i])/total);
      }  
    }
    return abs(entropy); // '-' in the Entropy formula
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
    this.onehops = onehops_;
    
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
    this.twohops = twohops_;
  }
  
  void getBottlenecks(){
    ArrayList <Tag> bottlenecks_ = new ArrayList();
    for(Tag tag : this.onehops){
      if(tag.entropy>0){
        bottlenecks_.add(tag);
      }
    }
    this.bottlenecks=bottlenecks_;
  }
  
  void getMostVulnNeighb(){
    ArrayList <Tag> most_vuln_ = new ArrayList();
    for(Tag tag: onehops){
      most_vuln_.add(tag); //Start with every onehop
    }
    float smallest_vp=10.0; // Start with a high value
    
    //Find the smallest vp in the onehops
    for(Tag tag : this.onehops){
      if(tag.vuln_prob<smallest_vp){
        smallest_vp=tag.vuln_prob; 
      }
    }
    
    // Remove all tags that have a higher vp than the smallest vp
    for(int i=most_vuln_.size()-1; i>=0; i--){
      if(onehops.get(i).vuln_prob>smallest_vp){
        most_vuln_.remove(i); // Remove the onehops that have a higher vp than other onehops
      }
    }
    this.most_vuln=most_vuln_;
  }
  
  // Smartly spreads the logs based on vp and entropy
  void spreadLog(int log_numb, int id){
    for(Tag tag : this.most_vuln){
      if(tag.vuln_prob<this.vuln_prob) tag.addLog(log_numb, id);
    }
  }
  
  void addLog(int log_numb, int id){
    boolean add=true;
    //Check that we don't alreayd have this log
    for (int i =0; i<this.logs.getRowCount();i++){
      int log_numb_=logs.getInt(i,"log_numb");
      if(log_numb==log_numb_) add=false;
    }
    if(add){
      TableRow newRow = this.logs.addRow();
      newRow.setInt("log_numb",log_numb);
      newRow.setInt("id", id);
      if(this.logs.getRowCount()>max_memory) max_memory= this.logs.getRowCount(); // Update global max memory (metric)
      if(log_numb==log_count && id== this.id) spreadLog(log_numb, id); // Smartly spread the log if it's new
    }
    if(!(log_numb==log_count && id== this.id)){ // If it is not a new log
      numb_comm+=1; // Count the communication that was made (5 x uint8)
    }
}
  
  // "caller" is the tag that called the function
  // "degree" is the depth since the first call. Used to indicate how many communications are needed for data retrieval
  Table extractLogsNetwork(Tag caller, int degree){
    Table all_logs = new Table();
    all_logs.addColumn("log_numb");
    all_logs.addColumn("id");
    
    for(int i =0;i<this.logs.getRowCount();i++){ // Exctract your own logs
      TableRow row= this.logs.getRow(i);
      numb_comm+=degree; // Add the number of communications needed for retrieval
      all_logs.addRow(row);
    }
    this.logs.clearRows(); // Delete your own logs
    
    // Extract your one-hops' logs (those that you don't have in common with the caller)
    for(int i=0;i<this.onehops.size();i++){
      if(onehops.get(i).logs.getRowCount()>=1 && (!ALmatch(onehops.get(i), caller.onehops) || caller==this)){
        Table new_table=new Table();
        new_table=onehops.get(i).extractLogsNetwork(this, degree+1); // Flagging yourself as the caller
        for(int j =0;j<new_table.getRowCount();j++){ // Merge with existing table
          TableRow row= new_table.getRow(j);
          all_logs.addRow(row);
        }
      }
    }
    return all_logs;
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
