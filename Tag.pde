int n_tags=0;
int beta =1; // Max number of paths to be considered vulnerable (Paramter for vulnerability probability calculation)
int tag_diameter;


class Tag {
  Tree tree;
  Table logs;
  final int id; 
  float entropy=0;
  float prev_entropy=0;
  float vuln_prob=0;
  float entr_grad=0; // How far you are from a bottleneck node
  int last_tags_size=0; // Value of the last grad update
  int last_grad_update_source;// Source (=tag id) of the last grad update 
  int last_log_transferred=-1; // For BN nodes: indicates the last log transfered
  //PVector suggested_new_cam;
  ArrayList <Tag> onehops; //One hop neighbours
  ArrayList <Tag> twohops; //two hop neighbours
  int neighb_change=0;
  ArrayList <Tag> bottlenecks_one; // Onehops that are bottleneck nodes
  ArrayList <Tag> bottlenecks_two; // Twohops that are bottleneck nodes
  //int[][] routes; // Routes for BN
  //ArrayList <IntList> routes; // Routes for BN
  ArrayList <ArrayList<Tag>> routes; // Routes for BN
  ArrayList <Tag> least_vuln; // List of least vulnerable one-hops
  
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
    bottlenecks_one= new ArrayList<Tag>();
    bottlenecks_two= new ArrayList<Tag>();
    //routes = new ArrayList<IntList>();
    routes = new ArrayList<ArrayList<Tag>>();
    connexed=false;
    prev_entropy=0.;
    entropy=0.;
    entr_grad=0;
    last_tags_size=0;
    last_log_transferred=-1;
    
    logs = new Table();
    logs.addColumn("log_numb");
    logs.addColumn("id");
    
    newNeighboursTimer = int(random(20));
  }
   
  void go () {
    increment();
    if(newNeighboursTimer==0){ // Rarely check neighbour connections (will change only if new node has been added)
      getNeighbours(); // Gets one-hops and two-hops
    }
    if(this.neighb_change>0){
      if(this.neighb_change == 5){
        //numb_setup_comm+=this.onehops.size(); // Warn neighbours about new two-hop + send new vp + send new entr
      }
      this.neighb_change--;
      calcVulnProb(); // Compute vp and entropy
      getBottlenecks();
      getLeastVulnNeighb(); // Find the least vulnerable onehops
      if(gradient_on){
        if(this.entropy!=this.prev_entropy){
          if(this.prev_entropy>0) this.updateEntrGrad(-this.prev_entropy,this,this.id);
          if(this.entropy>0) this.updateEntrGrad(this.entropy,this,this.id);
        }
      }
    }
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
      //if(numbpaths==0) println("Error in numbpaths calculation");
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
    
    for(int i=0;i<total_unique_twohops.length;i++){
      if(total_unique_twohops[i]>=1){
        total_unique_twohops[i]--;
        total--;
      }
    }
    
    
    float entropy=0.0;
    int numb_routes=0;
    for (int i=0; i<total_unique_twohops.length;i++){
      if(total_unique_twohops[i]>0){
        numb_routes++;
        entropy+=((float)total_unique_twohops[i])/total*log(((float)total_unique_twohops[i])/total);
      }  
    }
    
    ////Manual resetting of entropies in certain cases
    //if(numb_routes==2){
    //  for(int i=0; i<total_unique_twohops.length;i++){
    //    if(total_unique_twohops[i]==1) return 0;         
    //  }
    //}
            
    if(numb_routes>1) this.routes=calcRoutes(total_unique_twohops, numb_routes);
    if(approx(abs(entropy),0.0)) return 0.0;
    else return abs(entropy); // '-' in the Entropy formula
  }
  
  ArrayList<ArrayList<Tag>> calcRoutes(float[] weights, int numb_routes){
    ArrayList<ArrayList<Tag>> routes_= new ArrayList<ArrayList<Tag>>(numb_routes);
    
    int route=0;
    for(int i=0;i<weights.length;i++){
      //println(weights.length + "  " + numb_routes+ "  " + i);
      if(weights[i]>0){
        ArrayList<Tag> one_route = new ArrayList<Tag>();
        for(int j=0;j<weights.length;j++){
          if(weights[j]==-i || j==i) one_route.add(this.onehops.get(j));
        }
        routes_.add(one_route);
        if(route < numb_routes-1) route++;
      }
    }
    
    return routes_;
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
  
  void getBottlenecks(){
    ArrayList <Tag> bottlenecks_one_ = new ArrayList();
    ArrayList <Tag> bottlenecks_two_ = new ArrayList();
    for(Tag tag : this.onehops){
      if(tag.entropy>0){
        bottlenecks_one_.add(tag);
      }
    }
    this.bottlenecks_one=bottlenecks_one_;
    
    for(Tag tag : this.twohops){
      if(tag.entropy>0){
        bottlenecks_two_.add(tag);
      }
    }
    this.bottlenecks_two=bottlenecks_two_;
  }
  
  void getLeastVulnNeighb(){
    ArrayList <Tag> least_vuln_ = new ArrayList();
    for(Tag tag: onehops){
      least_vuln_.add(tag); //Start with every onehop
    }
    //float smallest_vp=10.0; // Start with a high value
    
    ////Find the smallest vp in the onehops
    //for(Tag tag : this.onehops){
    //  if(tag.vuln_prob<smallest_vp){
    //    smallest_vp=tag.vuln_prob; 
    //  }
    //}
    
    // Remove all tags that have a higher vp than 0.8* ours 
    for(int i=least_vuln_.size()-1; i>=0; i--){
      if(onehops.get(i).vuln_prob>0.8*this.vuln_prob){
        least_vuln_.remove(i); // Remove the onehops that have a higher vp than other onehops
      }
    }
    this.least_vuln=least_vuln_;
  }  
  
  void updateEntrGrad(float value, Tag sender, int source_id){
    //println("I am : " + this.id +", sender : " + sender.id + ", source : " + source_id);
    
    if(source_id== this.id){ // If you're the source
      for(Tag tag : this.onehops){
        tag.updateEntrGrad(value/2, this, source_id);
      }
      this.prev_entropy=this.entropy;
    }
    
    else{ // If you're not the source
      numb_setup_comm++; // You've had to receive this info one way or another
      if(abs(value)>0.01){ 
        if(!((this.last_grad_update_source==source_id) && (tags.size()==this.last_tags_size))){ // If we haven't already received this update
          this.entr_grad+=value;
          this.last_tags_size=tags.size();
          this.last_grad_update_source=source_id;
        
          for(Tag tag : this.onehops){
            if (tag == sender || tag.id == source_id || ALmatch(tag, sender.onehops)) continue;
            else tag.updateEntrGrad(value/2, this, source_id);
          }
        }
      }
    }
  }
  
  //function called solely by BN !!
  void transferLog(int log_numb, int id, Tag sender){
    numb_comm++;
    int sender_id=sender.id;
    this.last_log_transferred=log_numb;
    
    //Find route of sender and source
    int route_sender=-1;
    int route_source=-1;
    for(int i=0;i<this.routes.size();i++){ //Run over the different routes
      for(int j = 0;j<this.routes.get(i).size();j++){ // Run over different nodes in one route
        if(this.routes.get(i).get(j).id==sender_id){
          route_sender=i;
        }
        if(this.routes.get(i).get(j).id==id){
          route_source=i;
        }
      }
    }
    //println("I am : " + this.id);
    
    //Send the log to all other routes (non-BN nodes)
    for(int i=0;i<this.routes.size();i++){ //Run over the different routes
      //IntList currentroute=this.routes.get(i);
      ArrayList<Tag> currentroute=this.routes.get(i);
      if(i==route_sender || i==route_source) continue;
      
      //check if they're not all BN (in which case skip the route completely)
      int numb_BN=0;
      int last_nonBN_index=-1;
      for(int j=0;j<currentroute.size();j++){
        if(currentroute.get(j).entropy>0){
          numb_BN++;
        }
        else last_nonBN_index=j;
      }
      if(numb_BN==currentroute.size()) continue;
      
      else if(currentroute.size()-numb_BN==1 && currentroute.get(last_nonBN_index).onehops.size()<=numb_BN+1){
        continue; // Don't send data if only one badly-connected non-BN
      }
      
      int transfer_id;
      if(vp_ON){
        int random_index= weighted_prob(currentroute, true);
        //do{
        //  random_index=(int)random(currentroute.size());
        //}while(currentroute.get(random_index).entropy>0); // Needs to not be a BN
        transfer_id = currentroute.get(random_index).id;
      }
      else{
        int random_index;
        do{
          random_index=(int)random(currentroute.size());
        }while(currentroute.get(random_index).entropy>0); // Needs to not be a BN
        transfer_id = currentroute.get(random_index).id;
      }
      
      for(int j=0; j<this.onehops.size(); j++){
        if(this.onehops.get(j).id==transfer_id){
          //println("Adding log to ID: "+this.onehops.get(j).id);
          this.onehops.get(j).addLog(log_numb, id);
          break;
        }
      }
    }
    
    // Stimulate highest other BN
    int highest_BN_index=-1;
    float highest_entropy=0;
    for(int i=0;i<this.bottlenecks_one.size();i++){
      if(bottlenecks_one.get(i).last_log_transferred!=log_numb){ 
        if(bottlenecks_one.get(i).entropy>highest_entropy){
          highest_BN_index=i;
          highest_entropy=bottlenecks_one.get(i).entropy;
        } 
      }
    }
    //Transferring log to BN with highest entropy
    if(highest_BN_index!=-1) bottlenecks_one.get(highest_BN_index).transferLog(log_numb, id, this);
    
    //for(Tag tag : bottlenecks_one){
    //  if(tag.last_log_transferred!=log_numb && !ALmatch(tag,sender.bottlenecks_one)) tag.transferLog(log_numb, id, this);
    //}
  }
  
  // Smartly spreads the logs based on vp and entropy
  void spreadLog(int log_numb, int id){ 
    if(id!=this.id) numb_comm++;
    
    //If vp is on and the log comes from you, follow vp 
    int vp_node_id=-1;
    if(vp_ON && id==this.id){
      int random_index= weighted_prob(this.onehops, BN_ON); // Ignore BNs if BNs are turned on
      if(random_index>=0){ 
        this.onehops.get(random_index).addLog(log_numb, id);
        //println("Following VP to ID: " + this.onehops.get(random_index).id);
        vp_node_id=this.onehops.get(random_index).id;
      }
    }
    
    // If we're a BN ourself, send the log to all routes without any BN node
    if(BN_ON && this.entropy>0){
      this.last_log_transferred=log_numb;
      for(int i=0;i<this.routes.size();i++){ //Run over the different routes
        ArrayList<Tag> currentroute=this.routes.get(i);
        
        //check if it has a BN in one-hops or two-hops (in which case skip the route completely)
        boolean any_BN=false;
        for(int j=0; j<currentroute.size();j++){
          if(currentroute.get(j).entropy>0 || currentroute.get(j).bottlenecks_one.size()>1){ // >1 as there is ourselves already ;)
            any_BN=true;
            break;
          }
        }
        //println("check completed :" + all_BN);
        if(any_BN) continue;
        if(currentroute.size()==1 && currentroute.get(0).id==vp_node_id) continue; // Don't send if we've already sent with vp
        
        int random_index;
        int transfer_id;
        do{
          random_index=(int)random(currentroute.size());
          transfer_id = currentroute.get(random_index).id;
        }while(currentroute.get(random_index).entropy>0 || transfer_id == vp_node_id); // Needs to not be a BN and ≠ vp_node_id
        //println("I am BN and new log sent to " + transfer_id);
       
        for(int j=0; j<this.onehops.size(); j++){
          if(this.onehops.get(j).id==transfer_id){
            this.onehops.get(j).addLog(log_numb, id);
            break;
          }
        }
      }
    }

    //Check for BN in onehops
    if(BN_ON && bottlenecks_one.size()!=0){
      float highest_entr=0.0;
      int highest_entr_index=-1;
      
      for(int i=0;i<bottlenecks_one.size();i++){
        if(bottlenecks_one.get(i).entropy>highest_entr){
          highest_entr=bottlenecks_one.get(i).entropy;
          highest_entr_index=i;
        }
      }
      
      //Sending log to nearby BN
      //println("New log sent to one-hop BN " +bottlenecks_one.get(highest_entr_index).id);
      bottlenecks_one.get(highest_entr_index).transferLog(log_numb, id, this);
    }
    
    
    //If no BN in one-hops, check in two-hops
    else if(BN_ON && two_hop_BN && bottlenecks_two.size()!=0){
      int max_number_links=0;
      int index=-1;
      for(int i=0;i<this.onehops.size();i++){
        if(this.onehops.get(i).id==id) continue;
        int number_links=0;
        for(int j=0;j<this.bottlenecks_two.size();j++){
          if(ALmatch(this.bottlenecks_two.get(j),this.onehops.get(i).onehops)) number_links++;
        }
        if(number_links>max_number_links){
          max_number_links=number_links;
          index=i; // spreadLog to the one-hop that is in contact with the most two-hop BN
        }
      }
      //println("New log sent to non-BN one-hop " + onehops.get(index).id);
      this.onehops.get(index).spreadLog(log_numb,id);
    }
    
    //If no BN anywhere and gradient ON, follow gradient
    else if(BN_ON && gradient_on){
      float highest_entr_grad=0.0;
      int highest_index=-1;
      for(int i=0;i<this.onehops.size();i++){
        if(this.onehops.get(i).entr_grad>highest_entr_grad){
          highest_index=i;
          highest_entr_grad=entr_grad;
        }
      }
      if(highest_entr_grad>0.0) this.onehops.get(highest_index).spreadLog(log_numb,id);
    }
  }
  
  // Receives log from other tag
  void addLog(int log_numb, int id){
    numb_comm++; // Count the communication that was made

    //Check that we don't alreayd have this log
    boolean add=true;
    for (int i =0; i<this.logs.getRowCount();i++){
      int log_numb_=logs.getInt(i,"log_numb");
      if(log_numb==log_numb_) add=false;
    }
    
    // If we don't already have it, add it
    if(add){
      TableRow newRow = this.logs.addRow();
      newRow.setInt("log_numb",log_numb);
      newRow.setInt("id", id);
      if(this.logs.getRowCount()>max_memory) max_memory= this.logs.getRowCount(); // Update global max memory (metric)
    }
  }
  
  // Creates new log and spreads it
  void newLog(int log_numb){
    TableRow newRow = this.logs.addRow();
    newRow.setInt("log_numb",log_numb);
    newRow.setInt("id", this.id);
    if(this.logs.getRowCount()>max_memory) max_memory= this.logs.getRowCount(); // Update global max memory (metric)
    spreadLog(log_numb, this.id); // Smartly spread the log 
  }
  
  // "caller" is the tag that called the function
  // "degree" is the depth since the first call. Used to indicate how many communications are needed for data retrieval
  Table extractLogsNetwork(Tag caller, int degree){
    this.retrieved=true;
    Table all_logs = new Table();
    all_logs.addColumn("log_numb");
    all_logs.addColumn("id");
    
    for(TableRow row : this.logs.rows()){ // Exctract your own logs
      if(row.getInt("id")!=caller.id || caller==this){
        numb_extr_comm+=degree; // Add the number of communications needed for retrieval
        all_logs.addRow(row);
      }
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
    this.connexed=true;
      
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

boolean contains(int[] arr, int val) {
  for(int i=0; i<arr.length; i++) {
    if(arr[i]==val) return true;
  }
  return false;
}

int weighted_prob(ArrayList<Tag> list, boolean ignore_BN){
  int index=-1;
  float total_vp=0;
  for(Tag tag : list){
    if(!ignore_BN || tag.entropy==0) total_vp+=(1-tag.vuln_prob);
  }
  
  float random_vp=random(total_vp);
  total_vp=0;
  for(int i=0;i<list.size();i++){
    if(!ignore_BN || list.get(i).entropy==0){
      total_vp+=(1-list.get(i).vuln_prob);
      if(total_vp>random_vp){
        index=i;
        break;
      }
    }
  }
  return index;
}

//Is approximately equal
boolean approx(float a ,float b){
  float epsilon=0.0001;
  if(abs(a-b)<epsilon) return true;
  return false;
}
