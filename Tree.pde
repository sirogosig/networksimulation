int tree_diameter;
int tree_distance;
class Tree {
   PVector pos;
   Tag tag;
   boolean tagged=false;
   
   Tree (float xx, float yy, boolean tagged) {
     pos = new PVector(xx,yy);
     this.tagged=tagged;
     if(tagged){
       this.tag= new Tag(this);
     }
   }
   
   void go () {
     
   }
   
   void tag() {
     this.tagged=true;
     this.tag = new Tag(this);
   }
   
   void draw () {
     noStroke();
     fill(20, 255, 90);
     if(tagged) {
       ellipse(pos.x, pos.y, tree_diameter, tree_diameter);
       this.tag.draw();
     }
     else ellipse(pos.x, pos.y, tree_diameter, tree_diameter);
   }
}
